-- ============================================================
-- ai_model.sql : MÔ HÌNH AI DỰ ĐOÁN KẾT QUẢ TRẬN ĐẤU (chạy hoàn toàn trong MySQL)
-- Thứ tự chạy:  schema.sql -> sample_data_v2.sql -> triggers.sql -> ai_model.sql
--
-- Mô hình: hồi quy logistic đa lớp (softmax) 3 lớp {Thắng nhà, Hòa, Thắng khách}.
-- Đầu vào (5 đặc trưng, tất cả là "đội nhà trừ đội khách", chỉ dùng dữ liệu TRƯỚC giờ đá):
--   ChenhPPG        chênh điểm trung bình mỗi trận từ đầu đến nay (có co về mức trung bình 1.3 điểm/trận)
--   ChenhHieuSo     chênh hiệu số bàn thắng bại mỗi trận từ đầu đến nay
--   ChenhPhongDo5   chênh số trận thắng trong 5 trận gần nhất / 5       (ThongKePhongDo)
--   ChenhGD5        chênh (bàn thắng TB - bàn thua TB) 5 trận gần nhất  (ThongKePhongDo)
--   ChenhNghi       chênh số ngày nghỉ (giới hạn [-7,7]) / 7            (ThongKePhongDo)
-- Trọng số được huấn luyện bằng ai_train.pl và lưu ở bảng MoHinhAI (cuối file).
-- ============================================================
USE QuanLyNgoaiHangAnh;

-- ------------------------------------------------------------
-- Bảng lưu trọng số mô hình (mỗi lớp một dòng)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MoHinhAI (
    Lop ENUM('Thắng nhà', 'Hòa', 'Thắng khách') PRIMARY KEY,
    HeSoTuDo          DOUBLE NOT NULL,
    W_ChenhPPG        DOUBLE NOT NULL,
    W_ChenhHieuSo     DOUBLE NOT NULL,
    W_ChenhPhongDo5   DOUBLE NOT NULL,
    W_ChenhGD5        DOUBLE NOT NULL,
    W_ChenhNghi       DOUBLE NOT NULL,
    TenMoHinh         VARCHAR(100) NOT NULL,
    SoMauHuanLuyen    INT NOT NULL,
    DoChinhXacCV      DECIMAL(5,2) NULL COMMENT 'Độ chính xác kiểm tra chéo 5-fold (%)',
    ThoiDiemHuanLuyen DATETIME NOT NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- View: kết quả của từng CLB trong từng trận đã đá (dạng "mỗi đội một dòng")
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_KetQuaTheoDoi AS
    SELECT MaCLBNha AS MaCLB, MaTD, ThoiGianThiDau AS ThoiGian,
           CAST(TiSoNha AS SIGNED) - CAST(TiSoKhach AS SIGNED) AS HieuSo,
           CASE WHEN TiSoNha > TiSoKhach THEN 3 WHEN TiSoNha = TiSoKhach THEN 1 ELSE 0 END AS Diem
      FROM TranDau WHERE TiSoNha IS NOT NULL AND TiSoKhach IS NOT NULL
    UNION ALL
    SELECT MaCLBKhach, MaTD, ThoiGianThiDau,
           CAST(TiSoKhach AS SIGNED) - CAST(TiSoNha AS SIGNED),
           CASE WHEN TiSoKhach > TiSoNha THEN 3 WHEN TiSoNha = TiSoKhach THEN 1 ELSE 0 END
      FROM TranDau WHERE TiSoNha IS NOT NULL AND TiSoKhach IS NOT NULL;

-- ------------------------------------------------------------
-- View: đặc trưng của mô hình cho từng trận có đủ thống kê phong độ của cả hai đội.
-- Dùng chung cho huấn luyện (ai_train.pl) và dự đoán (sp_DuDoanAI) => không bao giờ lệch nhau.
-- KetQua = kết quả thật (NULL nếu trận chưa đá).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_DacTrungDuDoan AS
SELECT t.MaTD, t.MaMuaGiai, t.ThoiGianThiDau,
       (h.p + 6.5) / (h.n + 5) - (a.p + 6.5) / (a.n + 5)               AS ChenhPPG,
       h.g / (h.n + 5) - a.g / (a.n + 5)                                AS ChenhHieuSo,
       (CAST(kh.SoTranThang5TranGanNhat AS SIGNED) - CAST(kk.SoTranThang5TranGanNhat AS SIGNED)) / 5    AS ChenhPhongDo5,
       (kh.TrungBinhBanThang - kh.TrungBinhBanThua)
         - (kk.TrungBinhBanThang - kk.TrungBinhBanThua)                 AS ChenhGD5,
       LEAST(7, GREATEST(-7, CAST(kh.SoNgayNghi AS SIGNED) - CAST(kk.SoNgayNghi AS SIGNED))) / 7 AS ChenhNghi,
       CASE WHEN t.TiSoNha IS NULL THEN NULL
            WHEN t.TiSoNha > t.TiSoKhach THEN 'Thắng nhà'
            WHEN t.TiSoNha = t.TiSoKhach THEN 'Hòa' ELSE 'Thắng khách' END AS KetQua
FROM TranDau t
JOIN ThongKePhongDo kh ON kh.MaTD = t.MaTD AND kh.MaCLB = t.MaCLBNha
JOIN ThongKePhongDo kk ON kk.MaTD = t.MaTD AND kk.MaCLB = t.MaCLBKhach
JOIN LATERAL (SELECT COUNT(*) AS n, IFNULL(SUM(r.Diem), 0) AS p, IFNULL(SUM(r.HieuSo), 0) AS g
                FROM vw_KetQuaTheoDoi r
               WHERE r.MaCLB = t.MaCLBNha AND r.ThoiGian < t.ThoiGianThiDau) h ON TRUE
JOIN LATERAL (SELECT COUNT(*) AS n, IFNULL(SUM(r.Diem), 0) AS p, IFNULL(SUM(r.HieuSo), 0) AS g
                FROM vw_KetQuaTheoDoi r
               WHERE r.MaCLB = t.MaCLBKhach AND r.ThoiGian < t.ThoiGianThiDau) a ON TRUE;

DELIMITER $$

-- ------------------------------------------------------------
-- Dự đoán một trận: tính xác suất bằng softmax rồi ghi vào DuDoanTranDau.
--   p_ChayLuc = thời điểm ghi nhận lần chạy (NULL => NOW()); phải trước giờ đá (trigger sẽ kiểm tra).
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DuDoanAI$$
CREATE PROCEDURE sp_DuDoanAI(IN p_MaTD VARCHAR(10), IN p_ChayLuc DATETIME)
BEGIN
    DECLARE v_ppg DOUBLE;  DECLARE v_hs DOUBLE;  DECLARE v_pd5 DOUBLE;  DECLARE v_gd5 DOUBLE;  DECLARE v_ng DOUBLE;
    DECLARE v_zh DOUBLE;   DECLARE v_zd DOUBLE;  DECLARE v_za DOUBLE;   DECLARE v_m DOUBLE;
    DECLARE v_eh DOUBLE;   DECLARE v_ed DOUBLE;  DECLARE v_ea DOUBLE;   DECLARE v_s DOUBLE;
    DECLARE v_p1 INT;      DECLARE v_p2 INT;     DECLARE v_p3 INT;
    DECLARE v_id VARCHAR(10);  DECLARE v_kq VARCHAR(20);

    SELECT ChenhPPG, ChenhHieuSo, ChenhPhongDo5, ChenhGD5, ChenhNghi, KetQua
      INTO v_ppg, v_hs, v_pd5, v_gd5, v_ng, v_kq
      FROM vw_DacTrungDuDoan WHERE MaTD = p_MaTD;
    IF v_ppg IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chưa đủ thống kê phong độ của hai đội để dự đoán trận này';
    END IF;

    SELECT HeSoTuDo + W_ChenhPPG*v_ppg + W_ChenhHieuSo*v_hs + W_ChenhPhongDo5*v_pd5 + W_ChenhGD5*v_gd5 + W_ChenhNghi*v_ng
      INTO v_zh FROM MoHinhAI WHERE Lop = 'Thắng nhà';
    SELECT HeSoTuDo + W_ChenhPPG*v_ppg + W_ChenhHieuSo*v_hs + W_ChenhPhongDo5*v_pd5 + W_ChenhGD5*v_gd5 + W_ChenhNghi*v_ng
      INTO v_zd FROM MoHinhAI WHERE Lop = 'Hòa';
    SELECT HeSoTuDo + W_ChenhPPG*v_ppg + W_ChenhHieuSo*v_hs + W_ChenhPhongDo5*v_pd5 + W_ChenhGD5*v_gd5 + W_ChenhNghi*v_ng
      INTO v_za FROM MoHinhAI WHERE Lop = 'Thắng khách';
    IF v_zh IS NULL OR v_zd IS NULL OR v_za IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chưa có trọng số mô hình trong bảng MoHinhAI';
    END IF;

    SET v_m = GREATEST(v_zh, v_zd, v_za);
    SET v_eh = EXP(v_zh - v_m), v_ed = EXP(v_zd - v_m), v_ea = EXP(v_za - v_m);
    SET v_s = v_eh + v_ed + v_ea;
    SET v_p1 = ROUND(100 * v_eh / v_s), v_p2 = ROUND(100 * v_ed / v_s);
    SET v_p3 = GREATEST(0, 100 - v_p1 - v_p2);
    IF v_p1 + v_p2 + v_p3 > 100 THEN SET v_p1 = 100 - v_p2 - v_p3; END IF;

    SELECT CONCAT('DD', LPAD(IFNULL(MAX(CAST(SUBSTRING(MaDuDoan, 3) AS UNSIGNED)), 0) + 1, 4, '0'))
      INTO v_id FROM DuDoanTranDau;
    INSERT INTO DuDoanTranDau (MaDuDoan, MaTD, XacSuatThangNha, XacSuatHoa, XacSuatThangKhach, NgayGioChayDuDoan, KetQuaThucTe)
    VALUES (v_id, p_MaTD, v_p1, v_p2, v_p3, IFNULL(p_ChayLuc, NOW()), v_kq);
END$$

-- ------------------------------------------------------------
-- Chạy mô hình cho mọi trận đã đủ thống kê mà chưa có dự đoán (an toàn khi chạy lại nhiều lần).
--   Trận đã đá  : ghi nhận như lần chạy lúc 09:00 ngày hôm trước giờ đá (dự đoán bổ sung cho dữ liệu lịch sử)
--   Trận chưa đá: ghi nhận lúc NOW()
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_DuDoanAITatCa$$
CREATE PROCEDURE sp_DuDoanAITatCa()
BEGIN
    DECLARE v_xong INT DEFAULT 0;
    DECLARE v_td VARCHAR(10);  DECLARE v_gio DATETIME;  DECLARE v_kq VARCHAR(20);
    DECLARE cur CURSOR FOR
        SELECT MaTD, ThoiGianThiDau, KetQua FROM vw_DacTrungDuDoan v
         WHERE NOT EXISTS (SELECT 1 FROM DuDoanTranDau d WHERE d.MaTD = v.MaTD)
         ORDER BY ThoiGianThiDau, MaTD;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_xong = 1;
    OPEN cur;
    lap: LOOP
        FETCH cur INTO v_td, v_gio, v_kq;
        IF v_xong = 1 THEN LEAVE lap; END IF;
        IF v_kq IS NULL THEN
            CALL sp_DuDoanAI(v_td, NOW());
        ELSE
            CALL sp_DuDoanAI(v_td, TIMESTAMP(DATE(v_gio) - INTERVAL 1 DAY, '09:00:00'));
        END IF;
    END LOOP;
    CLOSE cur;
END$$

-- ------------------------------------------------------------
-- Tự động chạy mô hình ngay khi có đủ thống kê phong độ của CẢ HAI đội cho một trận chưa đá
-- (thống kê được tạo bởi trigger trg_TranDau_au / sp_CapNhatPhongDo trong triggers.sql).
-- Lỗi của mô hình không bao giờ làm hỏng việc cập nhật thống kê.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ThongKe_ai$$
CREATE TRIGGER trg_ThongKe_ai AFTER INSERT ON ThongKePhongDo FOR EACH ROW
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;
    IF EXISTS (SELECT 1 FROM TranDau WHERE MaTD = NEW.MaTD AND TiSoNha IS NULL)
       AND (SELECT COUNT(*) FROM ThongKePhongDo WHERE MaTD = NEW.MaTD) = 2
       AND NOT EXISTS (SELECT 1 FROM DuDoanTranDau WHERE MaTD = NEW.MaTD) THEN
        CALL sp_DuDoanAI(NEW.MaTD, NOW());
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- Trọng số đã huấn luyện (ai_train.pl). Muốn huấn luyện lại: chạy ai_train.pl rồi nạp ai_weights.sql
-- ------------------------------------------------------------
REPLACE INTO MoHinhAI (Lop,HeSoTuDo,W_ChenhPPG,W_ChenhHieuSo,W_ChenhPhongDo5,W_ChenhGD5,W_ChenhNghi,TenMoHinh,SoMauHuanLuyen,DoChinhXacCV,ThoiDiemHuanLuyen) VALUES ('Thắng nhà',0.45739275,0.27422205,0.37038049,-0.03298877,-0.01122489,0.42293335,'Hồi quy logistic đa lớp (softmax)',500,53.80,NOW());
REPLACE INTO MoHinhAI (Lop,HeSoTuDo,W_ChenhPPG,W_ChenhHieuSo,W_ChenhPhongDo5,W_ChenhGD5,W_ChenhNghi,TenMoHinh,SoMauHuanLuyen,DoChinhXacCV,ThoiDiemHuanLuyen) VALUES ('Hòa',-0.38416631,-0.33698067,0.22024882,0.05285782,0.04017058,-0.20297793,'Hồi quy logistic đa lớp (softmax)',500,53.80,NOW());
REPLACE INTO MoHinhAI (Lop,HeSoTuDo,W_ChenhPPG,W_ChenhHieuSo,W_ChenhPhongDo5,W_ChenhGD5,W_ChenhNghi,TenMoHinh,SoMauHuanLuyen,DoChinhXacCV,ThoiDiemHuanLuyen) VALUES ('Thắng khách',-0.07322645,0.06275862,-0.59062931,-0.01986905,-0.02894569,-0.21995542,'Hồi quy logistic đa lớp (softmax)',500,53.80,NOW());

-- Chạy mô hình cho tất cả các trận đã có đủ thống kê phong độ (bỏ qua trận đã có dự đoán)
CALL sp_DuDoanAITatCa();
