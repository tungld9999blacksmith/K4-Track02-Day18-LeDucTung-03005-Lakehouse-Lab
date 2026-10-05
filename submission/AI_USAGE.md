# Khai báo sử dụng AI

**Công cụ:** Claude (Anthropic) qua Claude Code trong VS Code.

## AI đã hỗ trợ

| Hạng mục | Phạm vi |
|---|---|
| Đọc tài liệu và code | Tóm tắt README, `docs/`, giải thích từng notebook, các khái niệm (transaction log, Z-order, hidden partitioning, field-ID, CDF, provenance…) |
| Môi trường | Viết `make.ps1` (bản PowerShell của `Makefile`); |
| Hỗ trợ viết markdown | Review nhận xét, chỉnh sửa câu văn trong các nhận xét bổ sung trong 8 notebook, dựa trên output thực tế của lần chạy trên máy tôi |
| Phát hiện khi đối chiếu output | Lỗi múi giờ ở NB4; các dòng in sẵn dễ hiểu sai ở NB6 (`0 B`, "5 files", checkpoint `…099`) |
| Hướng dẫn nộp bài | Danh sách ảnh cần chụp, kiểm tra ảnh, nháp `INFO.md`, `REFLECTION.md` và file này |

## Tôi tự thực hiện và chịu trách nhiệm

- Đọc lại, chỉnh sửa và có thể tự giải thích toàn bộ Markdown, mã nguồn và số liệu trong bài.

## Cam kết

- Không có số liệu/output nào do AI tạo ra: mọi con số trong bài đến từ notebook chạy trên máy tôi.
- Không sửa logic pipeline, không bỏ assertion, không hạ ngưỡng để báo PASS; các cell AI thêm vào chỉ đọc dữ liệu để làm bằng chứng.
- Không gửi bí mật, API key hay dữ liệu cá nhân thật cho AI (lab dùng dữ liệu tổng hợp).
