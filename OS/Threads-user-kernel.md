# User mode, Kernel mode, User thread, Kernel thread và mô hình M:N

Tài liệu ghi chú để phân biệt các khái niệm hay bị lẫn khi học về thread, kèm ví dụ thực tế với Go.

---

## 1. User mode vs Kernel mode

Đây là **chế độ quyền hạn của CPU** tại từng thời điểm. Nó **không phải** là một loại thread.

| | User mode | Kernel mode |
|---|---|---|
| Ai chạy ở đây | Code chương trình của bạn, code thư viện, code runtime (vd: scheduler của Go) | Code của hệ điều hành (OS) |
| Quyền hạn | Bị giới hạn: không được đụng phần cứng trực tiếp, không được đọc/ghi vùng nhớ của kernel | Toàn quyền: điều khiển phần cứng, quản lý bộ nhớ, xếp lịch thread |
| Khi nào vào | Mặc định khi chạy chương trình | Khi có **system call** (`read`, `write`, `clone`...), **ngắt** (timer, phần cứng), hoặc **lỗi** (page fault, chia cho 0) |
| Chi phí chuyển | | Chuyển user → kernel → user tốn thời gian hơn một lời gọi hàm bình thường |

Một thread bình thường của bạn **chuyển qua lại** giữa hai chế độ:

```
Thread T1 của bạn:

[user mode]   tính toán a*b + c ...     ← phần lớn thời gian ở đây
     |
     | gọi read()  (system call)
     v
[kernel mode] OS đọc file giúp          ← VẪN là thread T1, chỉ tạm "vào" kernel
     |
     v
[user mode]   tính toán tiếp ...
```

**Ghi nhớ:** "đang ở kernel mode" nghĩa là CPU đang chạy code của OS với toàn quyền. Không có thread riêng nào "chuyên làm system call"; chính thread gọi system call sẽ tạm vào kernel mode.

---

## 2. User thread vs Kernel thread

| | User thread | Kernel thread (kernel-level thread) |
|---|---|---|
| Ai quản lý | Thư viện / runtime trong user space | Hệ điều hành |
| OS có biết nó tồn tại không | **Không** | **Có** |
| Bản chất | Chỉ là **một cục dữ liệu** trong bộ nhớ process: stack riêng + thanh ghi đã lưu + trạng thái | Thực thể được OS xếp lịch, **thực sự chạy trên core CPU** |
| Tự chạy được không | Không, phải "mượn" một kernel thread để chạy | Có |
| Chuyển đổi giữa các thread | Do runtime làm, ở **user mode**, rất nhanh (vài chục - vài trăm ns) | Do OS làm, ở **kernel mode**, chậm hơn (cỡ micro giây) |
| Chi phí tạo | Rất rẻ (goroutine: vài KB stack ban đầu) | Đắt hơn (stack thường 1–8 MB, phải gọi system call) |
| Ví dụ | Goroutine (Go), Java virtual thread, green thread đời đầu | Thread tạo bằng `pthread_create`, `std::thread`, `new Thread()` (Java platform thread) |

Có thể hình dung một user thread như sau:

```c
struct UserThread {
    void*     stack;   // vùng nhớ stack riêng
    Registers saved;   // thanh ghi lúc bị tạm dừng (gồm stack pointer, instruction pointer)
    int       state;   // đang chạy / chờ / sẵn sàng
};
```

**Ví dụ dễ nhớ:** user thread là **cuốn sách có kẹp bookmark** (ghi lại đang đọc tới đâu). Kernel thread là **người đọc**. OS chỉ phân người đọc vào các bàn (core), nó không biết gì về những cuốn sách.

---

## 3. Hai nghĩa của chữ "kernel thread"

Chữ "kernel thread" trong sách được dùng cho **hai thứ khác nhau**. Đây là chỗ dễ nhầm nhất.

| | Nghĩa A: Kernel thread chạy code của **user** | Nghĩa B: Kernel thread chạy code của **kernel** |
|---|---|---|
| Tên gọi chính xác hơn | Kernel-level thread / thread do kernel quản lý | Kernel-only thread / thread nội bộ của OS |
| Code nó chạy | Code chương trình của bạn (phần lớn ở user mode, chỉ vào kernel mode khi gọi system call) | Chỉ code của kernel, luôn ở kernel mode |
| Ai tạo | Chương trình của bạn (`pthread_create`, runtime Go gọi `clone()`...) | Chính OS |
| Thuộc process nào | Thuộc process của chương trình bạn, dùng chung bộ nhớ với các thread khác trong process | Không thuộc chương trình nào của người dùng |
| Ví dụ trên Linux | Các thread của chương trình Go, Java, C++ | `[kworker/0:1]`, `[kswapd0]`, `[ksoftirqd/0]` (thấy khi gõ `ps aux`, tên nằm trong ngoặc vuông) |
| Dùng trong mô hình 1:1, M:1, M:N | **Có**, đây là nghĩa được dùng | Không liên quan |

**Ghi nhớ:** khi nói "trong mô hình 1:1, mỗi thread của bạn là một kernel thread", ý là theo **nghĩa A**: OS **nhìn thấy** và **phân core** cho từng thread đó. Thread đó vẫn chạy code của bạn.

---

## 4. Các mô hình 1:1, M:1, M:N

"Mapping" giữa user thread và kernel thread nghĩa là: **kernel thread nào đang nạp trạng thái của user thread nào vào CPU và chạy code của nó**.

Trong M:1 và M:N, mỗi kernel thread chạy một vòng lặp scheduler của runtime (ở user mode) như sau:

```c
// chạy trên MỘT kernel thread, ở user mode
while (true) {
    UserThread* t = lay_thread_san_sang_tiep_theo();
    nap_thanh_ghi(t->saved);    // CPU nhảy vào code của t, chạy tiếp từ chỗ dừng lần trước
    // (code scheduler chỉ chạy lại khi t yield / phải chờ / bị ép nhường lượt)
    luu_thanh_ghi(&t->saved);   // lưu lại "bookmark" của t
}
```

Một bản vòng lặp = một kernel thread. Số kernel thread quyết định **tối đa bao nhiêu core** được dùng cùng lúc.

### 4.1. Mô hình 1:1 (phổ biến nhất)

Mỗi thread bạn tạo **là** một kernel thread. Không cần scheduler trong user space; OS tự chuyển đổi và phân core.

```
Thread:   T1  T2  T3 ... T10
           |   |   |      |
Core:     C1  C2  C3 ... C10      → song song thật
```

Ví dụ: C/C++ (`pthread`, `std::thread`), Java platform thread, Rust `std::thread`, C#.

Ưu điểm: song song thật trên nhiều core; một thread bị chặn trong system call không ảnh hưởng thread khác. Nhược điểm: tạo và chuyển đổi tốn kém, không tạo được hàng chục nghìn thread một cách rẻ.

### 4.2. Mô hình M:1 (cũ, hiếm)

M user thread chạy chung trên **1** kernel thread.

```
Thread:   T1  T2  T3 ... T10
            \  |  |     /
          1 kernel thread
                 |
Core:           C1                → chỉ 1 core, các core khác bỏ trống
```

Ví dụ: green thread của Java đời đầu, GNU Pth.

Ưu điểm: tạo và chuyển đổi cực rẻ, không cần OS hỗ trợ thread. Nhược điểm:

- **Không song song được**: 10 thread tính toán thuần trên máy 10 core vẫn chỉ chạy trên 1 core, không nhanh hơn 1 thread (còn chậm hơn chút vì chi phí chuyển đổi).
- **Một system call chặn là chặn tất cả**: nếu một user thread gọi `read()` chặn, kernel thread duy nhất bị chặn, mọi user thread đều đứng.

### 4.3. Mô hình M:N (lai)

M user thread (có thể rất nhiều) được chia ra trên **N** kernel thread (thường N = số core).

```
10.000 user thread  →  N kernel thread (K1..K10)  →  10 core
```

Ví dụ: Go (goroutine), Java 21 virtual thread, Erlang/BEAM, các async runtime như Tokio (Rust).

Ưu điểm: vừa tạo được rất nhiều thread nhẹ, vừa song song thật trên nhiều core. Nhược điểm: runtime phức tạp.

### 4.4. Một số điểm hay hiểu nhầm

- **K1..K10 là các kernel thread trong cùng MỘT process**, không phải 10 process. Chúng dùng chung bộ nhớ, nhờ đó mới dùng chung được hàng đợi user thread, và một user thread có thể đang chạy trên K1 rồi lát sau chạy tiếp trên K7.
- **Số kernel thread không được quyết định lúc biên dịch.** File thực thi chỉ chứa lệnh kiểu "đếm số core rồi tạo từng đó thread". Cùng một file Go chạy trên máy 8 core sẽ có khoảng 8 thread, trên máy 64 core có khoảng 64 thread.
- **10 thread trên 10 core không nhanh hơn đúng 10 lần.** Thường chỉ được 6–9 lần do: phần code tuần tự (định luật Amdahl), chi phí đồng bộ, tranh chấp băng thông RAM và cache, Hyper-Threading (core logic khác core vật lý), xung nhịp giảm khi tất cả core cùng chạy.
- **CPython là ngoại lệ:** thread là kernel thread thật (1:1), nhưng GIL chỉ cho một thread chạy bytecode Python tại một thời điểm, nên tính toán thuần không nhanh hơn.

### 4.5. Bảng tổng kết

| | 1:1 | M:1 | M:N |
|---|---|---|---|
| Số kernel thread | = số thread bạn tạo | 1 | N (thường = số core) |
| Song song trên nhiều core | Có | **Không** | Có |
| Chuyển đổi thread | OS làm, kernel mode | Runtime làm, user mode | Runtime làm, user mode (OS vẫn chuyển giữa các K) |
| System call chặn | Chỉ chặn thread đó | Chặn **tất cả** | Runtime xử lý (tạo/chuyển kernel thread khác) |
| Tạo rất nhiều thread | Tốn kém | Rẻ | Rẻ |
| Ví dụ | C/C++, Java platform thread, Rust | Java green thread cũ, GNU Pth | Go, Java virtual thread, Erlang |

---

## 5. Ví dụ M:N với Go

### 5.1. Mô hình G-M-P của Go

Runtime Go dùng ba loại đối tượng:

| Tên | Là gì | Tương ứng |
|---|---|---|
| **G** (goroutine) | Struct `g` chứa stack và trạng thái đã lưu (`g.sched`, kiểu `gobuf`: sp, pc, bp...) | User thread |
| **M** (machine) | Một OS thread thật, tạo bằng `clone()` trên Linux | Kernel thread |
| **P** (processor) | "Giấy phép" để chạy code Go, mỗi P có một hàng đợi G cục bộ | Số P = `GOMAXPROCS` = mặc định số core |

Một M phải giữ một P thì mới chạy được G. Vì có `GOMAXPROCS` cái P, nên tối đa `GOMAXPROCS` goroutine chạy code Go **cùng lúc**.

```
        P1 [G G G]       P2 [G G]        P3 [G G G G]      ← hàng đợi cục bộ
         |                |               |
         M1               M2              M3               ← OS thread
         |                |               |
       Core 1           Core 2          Core 3

   Hàng đợi toàn cục: [G G ...]
```

Khi một P hết việc, M của nó sẽ lấy G từ hàng đợi toàn cục hoặc **"ăn trộm" một nửa** hàng đợi của P khác (*work stealing*).

Số OS thread thực tế thường nhỉnh hơn `GOMAXPROCS` một chút: có thread `sysmon` giám sát, và khi một goroutine bị kẹt trong system call chặn, runtime giao P cho M khác (tạo mới nếu cần) để core không bị bỏ trống.

### 5.2. Ví dụ 1: tính toán song song, so sánh 1 goroutine và nhiều goroutine

```go
package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

// Tính toán thuần CPU, không có I/O
func work(start, end int) int64 {
	var s int64
	for i := start; i < end; i++ {
		s += int64(i%7) * int64(i%13)
	}
	return s
}

func main() {
	const N = 2_000_000_000
	numG := runtime.NumCPU()

	fmt.Println("Số core:", runtime.NumCPU())
	fmt.Println("GOMAXPROCS:", runtime.GOMAXPROCS(0)) // 0 = chỉ đọc, không đổi

	// Chạy với 1 goroutine
	t := time.Now()
	r1 := work(0, N)
	d1 := time.Since(t)
	fmt.Printf("1 goroutine:   kết quả=%d, thời gian=%v\n", r1, d1)

	// Chia ra numG goroutine
	t = time.Now()
	results := make([]int64, numG)
	chunk := N / numG
	var wg sync.WaitGroup

	for id := 0; id < numG; id++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			start := id * chunk
			end := start + chunk
			if id == numG-1 {
				end = N // goroutine cuối lấy phần dư
			}
			results[id] = work(start, end) // mỗi goroutine ghi vào ô riêng, không cần lock
		}(id)
	}
	wg.Wait()

	var r2 int64
	for _, v := range results {
		r2 += v
	}
	d2 := time.Since(t)
	fmt.Printf("%d goroutine: kết quả=%d, thời gian=%v\n", numG, r2, d2)
	fmt.Printf("Tăng tốc: %.2f lần\n", float64(d1)/float64(d2))
}
```

Chạy thử:

```bash
go run main.go                  # dùng mọi core → tăng tốc gần bằng số core vật lý
GOMAXPROCS=1 go run main.go     # chỉ 1 P → tăng tốc ~1 lần, giống hệt hạn chế của M:1
```

Lần chạy thứ hai cho thấy rõ ý chính: **số goroutine không quyết định mức song song; số kernel thread được phép chạy code Go cùng lúc mới quyết định.**

### 5.3. Ví dụ 2: 10.000 goroutine nhưng chỉ vài OS thread

```go
package main

import (
	"fmt"
	"os"
	"runtime"
	"time"
)

func main() {
	for i := 0; i < 10_000; i++ {
		go func() {
			time.Sleep(time.Minute) // goroutine đang ngủ không giữ OS thread nào
		}()
	}

	fmt.Println("PID:", os.Getpid())
	fmt.Println("Số goroutine:", runtime.NumGoroutine())
	fmt.Println("Kiểm tra số OS thread bằng lệnh bên dưới trong 60 giây tới...")
	time.Sleep(time.Minute)
}
```

Trong lúc chương trình chạy, mở terminal khác (Linux):

```bash
ps -o pid,nlwp,cmd -p <PID>     # nlwp = số thread (kernel thread) của process
ls /proc/<PID>/task/ | wc -l    # mỗi thư mục con là một kernel thread
```

Kết quả: khoảng **10.001 goroutine** nhưng chỉ **khoảng chục OS thread**, tất cả nằm trong **một PID duy nhất**. 10.000 goroutine chỉ là 10.000 struct trong bộ nhớ, OS không biết chúng tồn tại.

---

## 6. Lưu trạng thái thread: ở user mode hay kernel mode?

Tùy vào **ai** chuyển đổi:

| Loại chuyển đổi | Ai làm | Chạy ở mode nào | Lưu vào đâu |
|---|---|---|---|
| User thread A → user thread B (goroutine → goroutine) | Runtime, chạy trên kernel thread K1 | **User mode**, không có system call | Struct của A trong bộ nhớ process (`g.sched` trong Go) |
| Kernel thread → kernel thread | OS | **Kernel mode** | Kernel stack của thread và `task_struct` (Linux) |

Khi runtime chuyển từ A sang B, câu chính xác là: **"Kernel thread K1, đang ở user mode, chạy code scheduler của runtime: lưu A, nạp B, rồi chạy B."** Kernel (OS) không làm việc này và không hề biết A, B tồn tại. Với OS, K1 vẫn chạy liên tục.

Trong M:N có **hai tầng chuyển đổi độc lập**:

```
Tầng runtime (user mode):   goroutine A ⇄ goroutine B    trên kernel thread K1
Tầng OS (kernel mode):      K1 ⇄ thread khác              trên core 1
```

Nếu OS ngắt K1 trong lúc K1 đang chạy A, kernel lưu thanh ghi của K1 (lúc đó đang chứa trạng thái của A). Kernel chỉ biết mình lưu "K1", nhưng khi K1 chạy lại thì A cũng chạy tiếp như chưa có gì.

---

## 7. K1 đang lưu trạng thái của A thì bị OS ngắt: có bị ghi dở không?

### 7.1. Có thể bị ngắt giữa chừng, nhưng không gây lỗi

OS có thể ngắt K1 ở **bất kỳ lệnh nào**, kể cả giữa lúc K1 đang ghi trạng thái của A. Điều này vô hại vì OS ngắt một cách **trong suốt**:

- OS lưu **toàn bộ** thanh ghi của K1, gồm instruction pointer đang trỏ đúng vào giữa đoạn code lưu trạng thái.
- Phần dữ liệu của A đã ghi được vẫn **nằm nguyên trong bộ nhớ**. Phần chưa kịp ghi vẫn còn trong thanh ghi của K1, đã được OS cất giữ.
- Khi K1 chạy lại, OS nạp lại đúng các thanh ghi đó, K1 **chạy tiếp từ đúng lệnh bị dừng** và ghi nốt phần còn lại.

```
K1:  [lưu A: ghi SP] → [lưu A: ghi PC] ✂ bị OS ngắt
                                         ... K1 nằm chờ, struct A ghi dở ...
                                       ▶ K1 chạy lại
     [lưu A: ghi nốt] → [nạp B] → [chạy B]
```

### 7.2. Nguy hiểm thật sự: kernel thread khác đụng vào A đang ghi dở

Trong M:N, nếu lúc K1 đang nằm chờ mà K2 lấy A ra chạy, K2 sẽ nạp một trạng thái **ghi dở** và chương trình hỏng. Nguyên tắc chống lại: **chỉ công bố A là "sẵn sàng" SAU KHI đã lưu xong hoàn toàn.**

1. Lưu **đầy đủ** trạng thái của A.
2. **Sau đó** mới đổi trạng thái A thành "sẵn sàng" và đưa A vào hàng đợi.

Trước khi xong bước 1, A không nằm trong hàng đợi nào, nên không kernel thread nào khác thấy được A.

### 7.3. Go xử lý cụ thể như thế nào

**Trạng thái goroutine được đổi bằng phép toán nguyên tử.** Mỗi `g` có trường trạng thái (`_Grunning`, `_Grunnable`, `_Gwaiting`...). Runtime đổi trạng thái bằng `casgstatus`, dùng compare-and-swap nguyên tử, nên các M khác không bao giờ thấy trạng thái "ở giữa chừng".

**Thứ tự: lưu trước, công bố sau.** Ví dụ khi goroutine phải chờ (vd: đọc channel rỗng), runtime gọi `gopark`, đi qua `mcall`:

1. `mcall` (assembly) lưu PC, SP của goroutine hiện tại vào `g.sched`, rồi chuyển sang stack riêng của scheduler (`g0` của M đó).
2. Trên `g0`, runtime đổi trạng thái G từ `_Grunning` sang `_Gwaiting` (hoặc `_Grunnable` rồi mới đưa vào hàng đợi, nếu là nhường lượt).
3. Gọi `schedule()` để chọn G tiếp theo, rồi `gogo(&g.sched)` nạp trạng thái của G đó và nhảy vào code của nó.

Nếu OS ngắt M giữa bước 1, G vẫn ở trạng thái `_Grunning` và **không nằm trong hàng đợi nào**. Work stealing chỉ lấy G từ hàng đợi của các P khác, và hàng đợi chỉ chứa G đã `_Grunnable`, nên không M nào khác lấy được G đang ghi dở.

**Vì sao `gobuf` chỉ cần vài thanh ghi?** Chuyển đổi kiểu hợp tác xảy ra tại một lời gọi hàm. Theo quy ước gọi hàm của Go, tại điểm gọi hàm trình biên dịch đã cất các giá trị còn dùng ra stack rồi, nên chỉ cần lưu SP, PC, BP và vài trường khác.

**Ép nhường lượt bất đồng bộ (từ Go 1.14) có tính đến chỗ không an toàn.** Thread `sysmon` phát hiện goroutine chạy quá lâu (khoảng 10ms) sẽ gửi tín hiệu `SIGURG` tới M đang chạy nó. Trình xử lý tín hiệu chỉ ép nhường lượt nếu goroutine đang ở **điểm an toàn**: không ép khi đang ở giữa code của runtime (như đoạn đang chuyển đổi goroutine). Nếu ép được, nó chèn lời gọi `asyncPreempt`, hàm này lưu **toàn bộ** thanh ghi lên stack của goroutine rồi mới đi vào scheduler.

**OS ngắt M chỉ là vấn đề hiệu năng, không phải đúng sai.** Go không biết khi nào OS ngắt M. Trong lúc đó P vẫn thuộc về M đang bị dừng, nhưng các M khác vẫn có thể ăn trộm các G *khác* đang nằm trong hàng đợi của P đó. Nếu M bị chặn trong system call lâu, `sysmon` lấy lại P và giao cho M khác (`handoffp`).

### 7.4. Còn M:1 thì sao?

M:1 chỉ có một kernel thread, nên không có K2 nào tranh giành; việc OS ngắt giữa chừng vô hại như mục 7.1. Rủi ro ở M:1 là **tín hiệu hẹn giờ** do chính thư viện dùng để ép nhường lượt: nếu tín hiệu đến đúng lúc đang chuyển đổi, scheduler bị gọi lồng vào chính nó. Vì vậy các thư viện thường **tạm chặn tín hiệu** trong đoạn chuyển đổi.

---

## 8. Tóm tắt một trang

- **User mode / kernel mode** là chế độ quyền hạn của CPU. Một thread chuyển qua lại giữa hai chế độ khi gọi system call.
- **User thread** là dữ liệu (stack + thanh ghi đã lưu) do runtime quản lý, OS không biết. **Kernel thread** là thứ OS biết và đưa lên core.
- "Kernel thread" có **hai nghĩa**: thread do kernel quản lý chạy code của bạn (dùng trong 1:1, M:N), và thread nội bộ của OS chạy code kernel (`kworker`...).
- **1:1** song song thật, tạo tốn kém. **M:1** rẻ nhưng chỉ dùng 1 core. **M:N** vừa rẻ vừa song song.
- **Go** là M:N: nhiều goroutine (G) chạy trên vài OS thread (M), giới hạn bởi số P = `GOMAXPROCS`.
- Chuyển goroutine diễn ra ở **user mode**; chuyển kernel thread diễn ra ở **kernel mode**.
- Bị OS ngắt giữa lúc lưu trạng thái là **vô hại** vì OS trả lại nguyên vẹn. Go chống việc M khác chạm vào G đang ghi dở bằng **CAS nguyên tử trên trạng thái** và nguyên tắc **lưu xong mới đưa vào hàng đợi**.