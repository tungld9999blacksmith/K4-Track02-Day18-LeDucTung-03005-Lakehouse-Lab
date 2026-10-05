# Reflection — Anti-pattern: small files và thiếu job bảo trì

Hệ thống tôi quan tâm là log LLM/agent cho ứng dụng AI: mỗi request là một sự kiện nhỏ,
ingest liên tục theo micro-batch — đúng điều kiện sinh ra **small-file problem**.
Lab cho thấy nó âm thầm thế nào: 200 commit đều đúng nhưng tạo 200 file ~51 KB (NB6);
truy vấn điểm phải mở cả 200 file vì min/max của mọi file phủ toàn dải `user_id` (NB2);
ở Iceberg, metadata còn lớn gấp ~3 lần dữ liệu (NB5).

Bảo trì phải được thiết kế cùng pipeline. Tôi sẽ tăng kích thước batch khi ghi;
lên lịch compaction và clustering theo cột hay lọc; chạy VACUUM/expiry với retention ≥ 7 ngày
kèm bước dọn orphan có ngưỡng tuổi, vì expiry chỉ bỏ tham chiếu chứ không xoá file (NB6);
và cảnh báo theo số file mỗi partition. Quan trọng nhất: kiểm chứng hành vi của đúng engine đang dùng.

**Sử dụng AI:** Claude (Claude Code) hỗ trợ giải thích khái niệm, đọc code, viết nháp Markdown
và cell kiểm tra; tôi tự chạy và đối chiếu số liệu. Chi tiết: [AI_USAGE.md](AI_USAGE.md).
