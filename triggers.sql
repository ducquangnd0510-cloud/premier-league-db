-- ============================================================
-- triggers.sql : các ràng buộc nghiệp vụ mà schema.sql (CHECK/FK) không thể diễn đạt
-- Thứ tự chạy:  schema.sql  ->  sample_data_v2.sql  ->  triggers.sql
-- (nạp dữ liệu sau khi đã tạo trigger cũng được, vì dữ liệu mẫu hợp lệ)
-- Yêu cầu MySQL 8.0+. Chạy bằng:  mysql -u root -p < triggers.sql
-- Quy ước bàn 'Phản lưới nhà': MaHD là hợp đồng của cầu thủ đá phản lưới,
-- bàn thắng được tính cho đội ĐỐI PHƯƠNG của cầu thủ đó.
-- ============================================================
USE QuanLyNgoaiHangAnh;

DELIMITER $$

-- ------------------------------------------------------------
-- Hàm: số bàn thắng được tính cho một CLB trong một trận (có loại trừ 1 bàn khi UPDATE)
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_SoBanThangCuaDoi$$
CREATE FUNCTION fn_SoBanThangCuaDoi(p_MaTD VARCHAR(10), p_MaCLB VARCHAR(10), p_BoQuaMaBT VARCHAR(10))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_so INT DEFAULT 0;
    SELECT COUNT(*) INTO v_so
    FROM BanThang b
    JOIN HopDong h ON h.MaHD = b.MaHD
    WHERE b.MaTD = p_MaTD
      AND b.MaBT <> IFNULL(p_BoQuaMaBT, '')
      AND ( (b.LoaiBanThang <> 'Phản lưới nhà' AND h.MaCLB = p_MaCLB)
         OR (b.LoaiBanThang =  'Phản lưới nhà' AND h.MaCLB <> p_MaCLB) );
    RETURN v_so;
END$$

-- ------------------------------------------------------------
-- 1. TRẬN ĐẤU
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_TranDau_bi$$
CREATE TRIGGER trg_TranDau_bi BEFORE INSERT ON TranDau FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM TranDau t
               WHERE DATE(t.ThoiGianThiDau) = DATE(NEW.ThoiGianThiDau)
                 AND (t.MaCLBNha   IN (NEW.MaCLBNha, NEW.MaCLBKhach)
                   OR t.MaCLBKhach IN (NEW.MaCLBNha, NEW.MaCLBKhach))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Một CLB không được có hai trận đấu trong cùng một ngày';
    END IF;
    IF (NEW.TiSoNha IS NULL) <> (NEW.TiSoKhach IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tỷ số nhà và khách phải cùng có giá trị hoặc cùng NULL';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_TranDau_bu$$
CREATE TRIGGER trg_TranDau_bu BEFORE UPDATE ON TranDau FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM TranDau t
               WHERE t.MaTD <> NEW.MaTD
                 AND DATE(t.ThoiGianThiDau) = DATE(NEW.ThoiGianThiDau)
                 AND (t.MaCLBNha   IN (NEW.MaCLBNha, NEW.MaCLBKhach)
                   OR t.MaCLBKhach IN (NEW.MaCLBNha, NEW.MaCLBKhach))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Một CLB không được có hai trận đấu trong cùng một ngày';
    END IF;
    IF (NEW.TiSoNha IS NULL) <> (NEW.TiSoKhach IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tỷ số nhà và khách phải cùng có giá trị hoặc cùng NULL';
    END IF;
    -- sửa tỷ số không được thấp hơn số bàn thắng đã ghi nhận chi tiết
    IF NOT (OLD.TiSoNha <=> NEW.TiSoNha AND OLD.TiSoKhach <=> NEW.TiSoKhach) THEN
        IF fn_SoBanThangCuaDoi(NEW.MaTD, NEW.MaCLBNha, NULL)   > IFNULL(NEW.TiSoNha, 0)
        OR fn_SoBanThangCuaDoi(NEW.MaTD, NEW.MaCLBKhach, NULL) > IFNULL(NEW.TiSoKhach, 0) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tỷ số mới thấp hơn số bàn thắng đã ghi nhận chi tiết';
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------
-- 2. HỢP ĐỒNG: không chồng thời gian hiệu lực của cùng một cầu thủ
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_HopDong_bi$$
CREATE TRIGGER trg_HopDong_bi BEFORE INSERT ON HopDong FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HopDong x
               WHERE x.MaCT = NEW.MaCT
                 AND x.NgayKy <= NEW.NgayKetThuc AND x.NgayKetThuc >= NEW.NgayKy) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hợp đồng chồng thời gian với hợp đồng khác của cùng cầu thủ';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_HopDong_bu$$
CREATE TRIGGER trg_HopDong_bu BEFORE UPDATE ON HopDong FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM HopDong x
               WHERE x.MaCT = NEW.MaCT AND x.MaHD <> NEW.MaHD
                 AND x.NgayKy <= NEW.NgayKetThuc AND x.NgayKetThuc >= NEW.NgayKy) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hợp đồng chồng thời gian với hợp đồng khác của cùng cầu thủ';
    END IF;
END$$

-- ------------------------------------------------------------
-- 3. BÀN THẮNG
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_KiemTraBanThang$$
CREATE PROCEDURE sp_KiemTraBanThang(IN p_MaBT VARCHAR(10), IN p_MaTD VARCHAR(10), IN p_MaHD VARCHAR(10),
                                    IN p_Loai VARCHAR(20), IN p_MaHDKT VARCHAR(10))
BEGIN
    DECLARE v_ngay DATE;  DECLARE v_nha VARCHAR(10);  DECLARE v_khach VARCHAR(10);
    DECLARE v_tsn INT;    DECLARE v_tsk INT;
    DECLARE v_clb_ghi VARCHAR(10);  DECLARE v_clb_kt VARCHAR(10);  DECLARE v_clb_tinh VARCHAR(10);
    DECLARE v_ts_doi INT;

    SELECT DATE(ThoiGianThiDau), MaCLBNha, MaCLBKhach, TiSoNha, TiSoKhach
      INTO v_ngay, v_nha, v_khach, v_tsn, v_tsk
      FROM TranDau WHERE MaTD = p_MaTD;
    IF v_tsn IS NULL OR v_tsk IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể ghi bàn thắng cho trận chưa có tỷ số';
    END IF;

    SELECT MaCLB INTO v_clb_ghi FROM HopDong
     WHERE MaHD = p_MaHD AND v_ngay BETWEEN NgayKy AND NgayKetThuc;
    IF v_clb_ghi IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hợp đồng của cầu thủ ghi bàn không còn hiệu lực tại thời điểm trận đấu';
    END IF;
    IF v_clb_ghi NOT IN (v_nha, v_khach) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cầu thủ ghi bàn không thuộc hai CLB của trận đấu';
    END IF;

    -- đội được tính bàn: phản lưới thì tính cho đối phương
    IF p_Loai = 'Phản lưới nhà' THEN
        SET v_clb_tinh = IF(v_clb_ghi = v_nha, v_khach, v_nha);
    ELSE
        SET v_clb_tinh = v_clb_ghi;
    END IF;

    IF p_MaHDKT IS NOT NULL THEN
        IF p_MaHDKT = p_MaHD THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Người kiến tạo phải khác người ghi bàn';
        END IF;
        SELECT MaCLB INTO v_clb_kt FROM HopDong
         WHERE MaHD = p_MaHDKT AND v_ngay BETWEEN NgayKy AND NgayKetThuc;
        IF v_clb_kt IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hợp đồng của cầu thủ kiến tạo không còn hiệu lực tại thời điểm trận đấu';
        END IF;
        IF v_clb_kt <> v_clb_tinh THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cầu thủ kiến tạo phải cùng đội với đội được tính bàn thắng';
        END IF;
    END IF;

    SET v_ts_doi = IF(v_clb_tinh = v_nha, v_tsn, v_tsk);
    IF fn_SoBanThangCuaDoi(p_MaTD, v_clb_tinh, p_MaBT) + 1 > v_ts_doi THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Số bàn thắng chi tiết vượt quá tỷ số của đội trong trận';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_BanThang_bi$$
CREATE TRIGGER trg_BanThang_bi BEFORE INSERT ON BanThang FOR EACH ROW
BEGIN
    CALL sp_KiemTraBanThang(NEW.MaBT, NEW.MaTD, NEW.MaHD, NEW.LoaiBanThang, NEW.MaHDKienTao);
END$$

DROP TRIGGER IF EXISTS trg_BanThang_bu$$
CREATE TRIGGER trg_BanThang_bu BEFORE UPDATE ON BanThang FOR EACH ROW
BEGIN
    CALL sp_KiemTraBanThang(NEW.MaBT, NEW.MaTD, NEW.MaHD, NEW.LoaiBanThang, NEW.MaHDKienTao);
END$$

-- ------------------------------------------------------------
-- 4. THẺ PHẠT
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_KiemTraThePhat$$
CREATE PROCEDURE sp_KiemTraThePhat(IN p_MaTD VARCHAR(10), IN p_MaHD VARCHAR(10))
BEGIN
    DECLARE v_ngay DATE;  DECLARE v_nha VARCHAR(10);  DECLARE v_khach VARCHAR(10);
    DECLARE v_tsn INT;    DECLARE v_clb VARCHAR(10);

    SELECT DATE(ThoiGianThiDau), MaCLBNha, MaCLBKhach, TiSoNha
      INTO v_ngay, v_nha, v_khach, v_tsn
      FROM TranDau WHERE MaTD = p_MaTD;
    IF v_tsn IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể ghi thẻ phạt cho trận chưa diễn ra (chưa có tỷ số)';
    END IF;
    SELECT MaCLB INTO v_clb FROM HopDong
     WHERE MaHD = p_MaHD AND v_ngay BETWEEN NgayKy AND NgayKetThuc;
    IF v_clb IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hợp đồng của cầu thủ nhận thẻ không còn hiệu lực tại thời điểm trận đấu';
    END IF;
    IF v_clb NOT IN (v_nha, v_khach) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cầu thủ nhận thẻ không thuộc hai CLB của trận đấu';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_ThePhat_bi$$
CREATE TRIGGER trg_ThePhat_bi BEFORE INSERT ON ThePhat FOR EACH ROW
BEGIN
    CALL sp_KiemTraThePhat(NEW.MaTD, NEW.MaHD);
END$$

DROP TRIGGER IF EXISTS trg_ThePhat_bu$$
CREATE TRIGGER trg_ThePhat_bu BEFORE UPDATE ON ThePhat FOR EACH ROW
BEGIN
    CALL sp_KiemTraThePhat(NEW.MaTD, NEW.MaHD);
END$$

-- ------------------------------------------------------------
-- 5. BỔ NHIỆM HLV: không chồng thời gian (cùng HLV, hoặc cùng CLB => tối đa 1 lượt đang hiệu lực)
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_BoNhiem_bi$$
CREATE TRIGGER trg_BoNhiem_bi BEFORE INSERT ON BoNhiemHLV FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM BoNhiemHLV x
               WHERE x.MaHLV = NEW.MaHLV
                 AND x.NgayBoNhiem <= IFNULL(NEW.NgayKetThuc, '9999-12-31')
                 AND IFNULL(x.NgayKetThuc, '9999-12-31') >= NEW.NgayBoNhiem) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HLV đã có lượt bổ nhiệm khác chồng thời gian';
    END IF;
    IF EXISTS (SELECT 1 FROM BoNhiemHLV x
               WHERE x.MaCLB = NEW.MaCLB
                 AND x.NgayBoNhiem <= IFNULL(NEW.NgayKetThuc, '9999-12-31')
                 AND IFNULL(x.NgayKetThuc, '9999-12-31') >= NEW.NgayBoNhiem) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CLB đã có HLV trưởng khác trong khoảng thời gian này';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_BoNhiem_bu$$
CREATE TRIGGER trg_BoNhiem_bu BEFORE UPDATE ON BoNhiemHLV FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM BoNhiemHLV x
               WHERE x.MaHLV = NEW.MaHLV AND x.MaBoNhiem <> NEW.MaBoNhiem
                 AND x.NgayBoNhiem <= IFNULL(NEW.NgayKetThuc, '9999-12-31')
                 AND IFNULL(x.NgayKetThuc, '9999-12-31') >= NEW.NgayBoNhiem) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HLV đã có lượt bổ nhiệm khác chồng thời gian';
    END IF;
    IF EXISTS (SELECT 1 FROM BoNhiemHLV x
               WHERE x.MaCLB = NEW.MaCLB AND x.MaBoNhiem <> NEW.MaBoNhiem
                 AND x.NgayBoNhiem <= IFNULL(NEW.NgayKetThuc, '9999-12-31')
                 AND IFNULL(x.NgayKetThuc, '9999-12-31') >= NEW.NgayBoNhiem) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CLB đã có HLV trưởng khác trong khoảng thời gian này';
    END IF;
END$$

-- ------------------------------------------------------------
-- 6. DỰ ĐOÁN
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_KiemTraDuDoan$$
CREATE PROCEDURE sp_KiemTraDuDoan(IN p_MaTD VARCHAR(10), IN p_ChayLuc DATETIME, IN p_KetQua VARCHAR(20))
BEGIN
    DECLARE v_gio DATETIME;  DECLARE v_tsn INT;  DECLARE v_tsk INT;
    DECLARE v_thuc VARCHAR(20);

    SELECT ThoiGianThiDau, TiSoNha, TiSoKhach INTO v_gio, v_tsn, v_tsk FROM TranDau WHERE MaTD = p_MaTD;
    IF p_ChayLuc >= v_gio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chỉ được tạo dự đoán trước giờ thi đấu (trận chưa diễn ra)';
    END IF;
    IF p_KetQua IS NOT NULL THEN
        IF v_tsn IS NULL OR v_tsk IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chỉ cập nhật Kết quả thực tế khi trận đã kết thúc và có tỷ số chính thức';
        END IF;
        SET v_thuc = CASE WHEN v_tsn > v_tsk THEN 'Thắng nhà' WHEN v_tsn = v_tsk THEN 'Hòa' ELSE 'Thắng khách' END;
        IF p_KetQua <> v_thuc THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Kết quả thực tế không khớp với tỷ số của trận';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_DuDoan_bi$$
CREATE TRIGGER trg_DuDoan_bi BEFORE INSERT ON DuDoanTranDau FOR EACH ROW
BEGIN
    CALL sp_KiemTraDuDoan(NEW.MaTD, NEW.NgayGioChayDuDoan, NEW.KetQuaThucTe);
END$$

DROP TRIGGER IF EXISTS trg_DuDoan_bu$$
CREATE TRIGGER trg_DuDoan_bu BEFORE UPDATE ON DuDoanTranDau FOR EACH ROW
BEGIN
    CALL sp_KiemTraDuDoan(NEW.MaTD, NEW.NgayGioChayDuDoan, NEW.KetQuaThucTe);
END$$

-- ------------------------------------------------------------
-- 7. THỐNG KÊ PHONG ĐỘ: CLB phải là một trong hai đội của trận
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ThongKe_bi$$
CREATE TRIGGER trg_ThongKe_bi BEFORE INSERT ON ThongKePhongDo FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TranDau WHERE MaTD = NEW.MaTD AND NEW.MaCLB IN (MaCLBNha, MaCLBKhach)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CLB không tham gia trận đấu của bản ghi thống kê phong độ';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_ThongKe_bu$$
CREATE TRIGGER trg_ThongKe_bu BEFORE UPDATE ON ThongKePhongDo FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TranDau WHERE MaTD = NEW.MaTD AND NEW.MaCLB IN (MaCLBNha, MaCLBKhach)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CLB không tham gia trận đấu của bản ghi thống kê phong độ';
    END IF;
END$$

-- ------------------------------------------------------------
-- 8. TỰ ĐỘNG CẬP NHẬT sau khi một trận có tỷ số:
--    (a) điền KetQuaThucTe cho các dự đoán của trận đó
--    (b) tính lại thống kê phong độ cho trận kế tiếp của hai CLB
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_CapNhatPhongDo$$
CREATE PROCEDURE sp_CapNhatPhongDo(IN p_MaCLB VARCHAR(10))
BEGIN
    DECLARE v_next VARCHAR(10);  DECLARE v_ko DATETIME;
    DECLARE v_so INT DEFAULT 0;  DECLARE v_thang INT DEFAULT 0;
    DECLARE v_gf DECIMAL(5,2) DEFAULT 0;  DECLARE v_ga DECIMAL(5,2) DEFAULT 0;
    DECLARE v_gannhat DATETIME;  DECLARE v_nghi INT DEFAULT 14;
    DECLARE v_id VARCHAR(10);

    SELECT MaTD, ThoiGianThiDau INTO v_next, v_ko
      FROM TranDau
     WHERE (MaCLBNha = p_MaCLB OR MaCLBKhach = p_MaCLB) AND TiSoNha IS NULL
     ORDER BY ThoiGianThiDau LIMIT 1;
    IF v_next IS NOT NULL THEN
        SELECT COUNT(*), IFNULL(SUM(f > g), 0), IFNULL(ROUND(AVG(f), 2), 0), IFNULL(ROUND(AVG(g), 2), 0)
          INTO v_so, v_thang, v_gf, v_ga
          FROM (SELECT IF(MaCLBNha = p_MaCLB, TiSoNha, TiSoKhach) AS f,
                       IF(MaCLBNha = p_MaCLB, TiSoKhach, TiSoNha) AS g
                  FROM TranDau
                 WHERE (MaCLBNha = p_MaCLB OR MaCLBKhach = p_MaCLB)
                   AND TiSoNha IS NOT NULL AND ThoiGianThiDau < v_ko
                 ORDER BY ThoiGianThiDau DESC LIMIT 5) x;
        SELECT MAX(ThoiGianThiDau) INTO v_gannhat
          FROM TranDau
         WHERE (MaCLBNha = p_MaCLB OR MaCLBKhach = p_MaCLB) AND TiSoNha IS NOT NULL AND ThoiGianThiDau < v_ko;
        IF v_gannhat IS NOT NULL THEN SET v_nghi = DATEDIFF(DATE(v_ko), DATE(v_gannhat)); END IF;

        SELECT CONCAT('TK', LPAD(IFNULL(MAX(CAST(SUBSTRING(MaThongKe, 3) AS UNSIGNED)), 0) + 1, 4, '0'))
          INTO v_id FROM ThongKePhongDo;
        INSERT INTO ThongKePhongDo
              (MaThongKe, MaCLB, MaTD, SoTranThang5TranGanNhat, TrungBinhBanThang, TrungBinhBanThua, SoNgayNghi, ThoiDiemTinh)
        VALUES (v_id, p_MaCLB, v_next, v_thang, v_gf, v_ga, v_nghi, NOW())
        ON DUPLICATE KEY UPDATE SoTranThang5TranGanNhat = VALUES(SoTranThang5TranGanNhat),
                                TrungBinhBanThang = VALUES(TrungBinhBanThang),
                                TrungBinhBanThua  = VALUES(TrungBinhBanThua),
                                SoNgayNghi = VALUES(SoNgayNghi),
                                ThoiDiemTinh = VALUES(ThoiDiemTinh);
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_TranDau_au$$
CREATE TRIGGER trg_TranDau_au AFTER UPDATE ON TranDau FOR EACH ROW
BEGIN
    IF NEW.TiSoNha IS NOT NULL AND NEW.TiSoKhach IS NOT NULL
       AND NOT (OLD.TiSoNha <=> NEW.TiSoNha AND OLD.TiSoKhach <=> NEW.TiSoKhach) THEN
        UPDATE DuDoanTranDau
           SET KetQuaThucTe = CASE WHEN NEW.TiSoNha > NEW.TiSoKhach THEN 'Thắng nhà'
                                   WHEN NEW.TiSoNha = NEW.TiSoKhach THEN 'Hòa' ELSE 'Thắng khách' END
         WHERE MaTD = NEW.MaTD;
        CALL sp_CapNhatPhongDo(NEW.MaCLBNha);
        CALL sp_CapNhatPhongDo(NEW.MaCLBKhach);
    END IF;
END$$

DELIMITER ;
