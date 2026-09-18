## Các thẻ HTML cơ bản
1. h1 - h6: heading
2. p: paragragh
3. img
4. a (anchor)
5. ul, li: ul-> unorder list, li -> list items
6. table
7. input
8. button
9. div

## Attributes

1. **id**: Định danh duy nhất cho một phần tử HTML.  
        *Ví dụ:* `<div id="header"></div>`

2. **class**: Gán tên lớp để áp dụng CSS hoặc JavaScript.  
        *Ví dụ:* `<p class="text-bold"></p>`

3. **src**: Đường dẫn đến tài nguyên (thường dùng cho hình ảnh, video).  
        *Ví dụ:* `<img src="image.jpg" alt="Example Image">`

4. **href**: Đường dẫn liên kết.  
        *Ví dụ:* `<a href="https://example.com">Visit Example</a>`

5. **style**: Áp dụng CSS trực tiếp cho phần tử.  
        *Ví dụ:* `<p style="color: red;">Hello</p>`

6. **alt**: Văn bản thay thế cho hình ảnh.  
        *Ví dụ:* `<img src="image.jpg" alt="Example Image">`

7. **title**: Hiển thị thông tin khi di chuột qua phần tử.  
        *Ví dụ:* `<button title="Click me">Click</button>`

8. **type**: Xác định kiểu của phần tử (thường dùng cho `<input>` hoặc `<button>`).  
        *Ví dụ:* `<input type="text">`

9. **name**: Tên của phần tử (thường dùng trong form).  
        *Ví dụ:* `<input name="username">`

10. **value**: Giá trị của phần tử (thường dùng trong form).  
         *Ví dụ:* `<input value="Default Text">`

11. **placeholder**: Văn bản gợi ý trong ô nhập liệu.  
         *Ví dụ:* `<input placeholder="Enter your name">`

12. **disabled**: Vô hiệu hóa phần tử.  
         *Ví dụ:* `<button disabled>Submit</button>`

13. **checked**: Đánh dấu trạng thái được chọn (thường dùng cho checkbox/radio).  
         *Ví dụ:* `<input type="checkbox" checked>`

14. **readonly**: Chỉ đọc, không cho phép chỉnh sửa.  
         *Ví dụ:* `<input type="text" readonly>`

15. **onclick**: Xử lý sự kiện khi nhấp chuột.  
         *Ví dụ:* `<button onclick="alert('Clicked!')">Click me</button>`

16. **onmouseover**: Xử lý sự kiện khi di chuột vào phần tử.  
         *Ví dụ:* `<div onmouseover="alert('Mouse over!')">Hover me</div>`

17. **onmouseout**: Xử lý sự kiện khi di chuột ra khỏi phần tử.  
         *Ví dụ:* `<div onmouseout="alert('Mouse out!')">Hover me</div>`

18. **width**: Đặt chiều rộng cho phần tử (thường dùng cho hình ảnh, video).  
         *Ví dụ:* `<img src="image.jpg" width="200">`

19. **height**: Đặt chiều cao cho phần tử (thường dùng cho hình ảnh, video).  
         *Ví dụ:* `<img src="image.jpg" height="150">`

## Cách sử dụng CSS trong HTML
1. **Inline CSS**: Sử dụng thuộc tính `style` trực tiếp trong thẻ HTML.  
   *Ví dụ:* `<p style="color: blue; font-size: 14px;">Hello World</p>`
2. **Internal CSS**: Sử dụng thẻ `<style>` trong phần `<head>` của tài liệu HTML.  
   *Ví dụ:*
   ```html
   <head>
     <style>
       p {
         color: green;
         font-size: 16px;
       }
     </style>
   </head>
   ```
3. **External CSS**: Liên kết tệp CSS bên ngoài bằng thẻ `<link>`.  
   *Ví dụ:*
   ```html
   <head>
     <link rel="stylesheet" type="text/css" href="styles.css">
   </head>
   ```
*This will match at least 2 out of the 4 terms in the name field*       

## ID và Class trong CSS selectors

1. **ID Selector**: Sử dụng dấu `#` theo sau bởi tên ID để chọn phần tử có ID đó.  
   *Ví dụ:*  
   ```css
   #header {
     background-color: blue;
   }
   ```
2. **Class Selector**: Sử dụng dấu `.` theo sau bởi tên class để chọn tất cả các phần tử có class đó.  
   *Ví dụ:*  
   ```css
   .text-bold {
     font-weight: bold;
   }
   ```

## Priority
1. Internal và External CSS có độ ưu tiên ngang nhau, cái nào được sự dụng phụ thuộc vào việc cái nào được khai báo trước
2. Inline CSS - 1000
3. ID Selector - 100
4. Class Selector - 10
5. Element Selector - 1 