# Thông tin bài nộp — K4-Track02-Day18 Lakehouse Lab

| Mục | Giá trị |
|---|---|
| Họ và tên | Le Duc Tung |
| MSSV | 03005 |
| Mã bài | K4-Track02-Day18 |
| Repo | `K4-Track02-Day18-LeDucTung-03005-Lakehouse-Lab` |
| Hình thức | Cá nhân |
| Đường chạy | **Lightweight** (`deltalake` 1.x + `pyiceberg` + DuckDB + Polars) cho **cả 8 notebook**; NB1–NB4 **không** dùng Spark |
| Python | 3.13.3 (venv `.venv`) |
| Hệ điều hành | Windows 11 Home Single Language (10.0.26300), PowerShell; lệnh `make` thay bằng `make.ps1` |
| AI sử dụng | Có — xem [AI_USAGE.md](AI_USAGE.md) |

## Kết quả kiểm tra (Part C — Reproducibility)

| Lệnh (PowerShell) | Kết quả |
|---|---|
| `.\.venv\Scripts\python.exe scripts/verify_lite.py` (smoke) | **9/9 PASS** |
| `.\.venv\Scripts\python.exe -m pytest` | **24/24 passed** |
| `.\.venv\Scripts\python.exe scripts/run_all.py` | **8/8 PASS** (~63 s) |

Ghi chú: `run_all.py` được chạy với `LAKEHOUSE_ROOT` trỏ tới một thư mục trống
(setup sạch — NB4/NB7/NB8 tự sinh dữ liệu thiếu). Khi chạy trên `_lakehouse/` mặc định
trong lúc notebook NB5/NB6 đang mở trong VS Code, Windows báo `PermissionError [WinError 32]`
vì kernel đang giữ file `catalog.db` của SQLite — lỗi khoá file của môi trường, không phải lỗi notebook.
Đóng/restart kernel trước khi chạy `run_all.py` để tránh.

## Nội dung bài nộp

| Thư mục / file | Nội dung |
|---|---|
| `notebooks/` | 8 notebook `.ipynb` đã thực thi, giữ output, có Markdown cell `📝 Nhận xét` giải thích số liệu và một số cell bằng chứng bổ sung |
| `screenshots/` | Ảnh kết quả chính của từng notebook (`nb01_*` … `nb08_*`) |
| `REFLECTION.md` | Reflection ≤ 200 từ |
| `AI_USAGE.md` | Khai báo phạm vi sử dụng AI |

## Thay đổi so với mã gốc

- **Không sửa logic pipeline, assertion hay ngưỡng** của 8 notebook (file `.py` gốc giữ nguyên).
- Chỉ **thêm** vào các `.ipynb` nộp bài: Markdown giải thích và một số code cell *chỉ đọc* để làm bằng chứng
  (ví dụ: so sánh version ở NB2/NB3, kiểm tra quy tắc Gold và minh hoạ múi giờ ở NB4, field-ID trong file Parquet cũ ở NB5,
  time travel sau DELETE ở NB7/NB8, fingerprint nội dung khi replay ở NB8).
- Thêm `make.ps1` ở thư mục gốc: bản PowerShell của các lệnh trong `Makefile` để chạy trên Windows.

## Những phát hiện đáng chú ý khi đối chiếu output

- **NB4:** `CAST(ts AS DATE)` dùng múi giờ của phiên DuckDB (`Asia/Bangkok`, UTC+7) nên Gold có 8 ngày (2 ngày biên thiếu dữ liệu) thay vì 7 ngày UTC. Vẫn đạt ngưỡng ≥ 7 ngày nhưng sai ngữ nghĩa — đã giải thích, không sửa code gốc.
- **NB6:** một số dòng in sẵn dễ hiểu sai — `(0 B)` khi vacuum dry-run (đường dẫn tương đối), "5 files you pay for" thực chất là 3 orphan + 2 checkpoint tự động, và `Checkpoint written: …099` là checkpoint tự động cũ (checkpoint mới ở v203).
- **NB7/NB8:** `DELETE` ở version hiện tại không xoá dữ liệu khỏi các version cũ — time travel vẫn đọc được cho tới khi VACUUM.
