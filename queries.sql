-- 1. Xem thông tin chi tiết một câu lạc bộ (sân nhà, huấn luyện viên hiện tại)
SELECT
    clb.MaCLB,
    clb.TenCLB,
    clb.SanNha,
    clb.ThanhPho,
    clb.NamThanhLap,
    hlv.HoTen AS HuanLuyenVienHienTai,
    bn.NgayBoNhiem
FROM CauLacBo clb
LEFT JOIN BoNhiemHLV bn
    ON clb.MaCLB = bn.MaCLB
    AND bn.NgayKetThuc IS NULL
LEFT JOIN HuanLuyenVien hlv
    ON bn.MaHLV = hlv.MaHLV
WHERE clb.MaCLB = 'CLB001';


-- 2. Tra cứu lý lịch thi đấu của một cầu thủ (các CLB đã khoác áo, thời gian)
SELECT
    ct.MaCT,
    ct.HoTen,
    clb.TenCLB,
    hd.NgayKy,
    hd.NgayKetThuc
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
JOIN CauLacBo clb ON hd.MaCLB = clb.MaCLB
WHERE ct.MaCT = 'CT001'
ORDER BY hd.NgayKy;


-- 3. Tìm kiếm cầu thủ theo quốc tịch hoặc vị trí thi đấu
SELECT *
FROM CauThu
WHERE QuocTich = 'Anh'
   OR ViTri = 'Tiền vệ';


-- 4. Xem lịch thi đấu của một câu lạc bộ trong một vòng đấu cụ thể
SELECT
    td.MaTD,
    mg.TenMuaGiai,
    td.VongDau,
    clbNha.TenCLB AS DoiNha,
    clbKhach.TenCLB AS DoiKhach,
    td.ThoiGianThiDau,
    td.SanVanDong,
    td.TiSoNha,
    td.TiSoKhach
FROM TranDau td
JOIN MuaGiai mg ON td.MaMuaGiai = mg.MaMuaGiai
JOIN CauLacBo clbNha ON td.MaCLBNha = clbNha.MaCLB
JOIN CauLacBo clbKhach ON td.MaCLBKhach = clbKhach.MaCLB
WHERE (td.MaCLBNha = 'CLB001'
       OR td.MaCLBKhach = 'CLB001')
  AND td.MaMuaGiai = 'MG001'
  AND td.VongDau = 10
ORDER BY td.ThoiGianThiDau;


-- 5. Tính tổng số bàn thắng của một cầu thủ trong một mùa giải
SELECT
    ct.MaCT,
    ct.HoTen,
    mg.TenMuaGiai,
    COUNT(bt.MaBT) AS TongBanThang
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
JOIN BanThang bt ON hd.MaHD = bt.MaHD
JOIN TranDau td ON bt.MaTD = td.MaTD
JOIN MuaGiai mg ON td.MaMuaGiai = mg.MaMuaGiai
WHERE ct.MaCT = 'CT095'
  AND mg.MaMuaGiai = 'MG001'
  AND bt.LoaiBanThang <> 'Phản lưới nhà'
GROUP BY ct.MaCT, ct.HoTen, mg.TenMuaGiai;


-- 6. Tính tỷ lệ thắng/hòa/thua của một CLB theo từng mùa giải
SELECT
    clb.TenCLB,
    mg.TenMuaGiai,
    COUNT(*) AS TongSoTran,
    SUM(
        CASE
            WHEN (td.MaCLBNha = clb.MaCLB
                  AND td.TiSoNha > td.TiSoKhach)
              OR (td.MaCLBKhach = clb.MaCLB
                  AND td.TiSoKhach > td.TiSoNha)
            THEN 1 ELSE 0
        END
    ) AS SoTranThang,
    SUM(
        CASE
            WHEN td.TiSoNha = td.TiSoKhach
            THEN 1 ELSE 0
        END
    ) AS SoTranHoa,
    SUM(
        CASE
            WHEN (td.MaCLBNha = clb.MaCLB
                  AND td.TiSoNha < td.TiSoKhach)
              OR (td.MaCLBKhach = clb.MaCLB
                  AND td.TiSoKhach < td.TiSoNha)
            THEN 1 ELSE 0
        END
    ) AS SoTranThua,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN (td.MaCLBNha = clb.MaCLB
                      AND td.TiSoNha > td.TiSoKhach)
                  OR (td.MaCLBKhach = clb.MaCLB
                      AND td.TiSoKhach > td.TiSoNha)
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    ) AS TyLeThang,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN td.TiSoNha = td.TiSoKhach
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    ) AS TyLeHoa,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN (td.MaCLBNha = clb.MaCLB
                      AND td.TiSoNha < td.TiSoKhach)
                  OR (td.MaCLBKhach = clb.MaCLB
                      AND td.TiSoKhach < td.TiSoNha)
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    ) AS TyLeThua
FROM CauLacBo clb
JOIN TranDau td
    ON td.MaCLBNha = clb.MaCLB
    OR td.MaCLBKhach = clb.MaCLB
JOIN MuaGiai mg ON td.MaMuaGiai = mg.MaMuaGiai
WHERE clb.MaCLB = 'CLB001'
  AND td.TiSoNha IS NOT NULL
  AND td.TiSoKhach IS NOT NULL
GROUP BY clb.MaCLB, clb.TenCLB, mg.MaMuaGiai, mg.TenMuaGiai;


-- 7. Liệt kê các trận đấu có tỷ số cách biệt từ 3 bàn trở lên
SELECT
    td.MaTD,
    mg.TenMuaGiai,
    clbNha.TenCLB AS DoiNha,
    clbKhach.TenCLB AS DoiKhach,
    td.TiSoNha,
    td.TiSoKhach,
    ABS(CAST(td.TiSoNha AS SIGNED) - CAST(td.TiSoKhach AS SIGNED)) AS CachBiet
FROM TranDau td
JOIN MuaGiai mg ON td.MaMuaGiai = mg.MaMuaGiai
JOIN CauLacBo clbNha ON td.MaCLBNha = clbNha.MaCLB
JOIN CauLacBo clbKhach ON td.MaCLBKhach = clbKhach.MaCLB
WHERE td.TiSoNha IS NOT NULL
  AND td.TiSoKhach IS NOT NULL
  AND ABS(CAST(td.TiSoNha AS SIGNED) - CAST(td.TiSoKhach AS SIGNED)) >= 3
ORDER BY CachBiet DESC;


-- 8. Tính số phút trung bình cầu thủ ghi bàn đầu tiên trong các trận đã thi đấu
SELECT
    ROUND(AVG(PhutDauTien), 2) AS TrungBinhPhutGhiBanDauTien
FROM (
    SELECT
        MaTD,
        MIN(PhutGhiBan) AS PhutDauTien
    FROM BanThang
    GROUP BY MaTD
) AS BangDauTien;


-- 9. Tính bảng xếp hạng đầy đủ của một mùa giải
WITH KetQua AS (
    SELECT
        MaCLBNha AS MaCLB,
        TiSoNha AS BanThang,
        TiSoKhach AS BanThua
    FROM TranDau
    WHERE MaMuaGiai = 'MG001'
      AND TiSoNha IS NOT NULL
      AND TiSoKhach IS NOT NULL

    UNION ALL

    SELECT
        MaCLBKhach AS MaCLB,
        TiSoKhach AS BanThang,
        TiSoNha AS BanThua
    FROM TranDau
    WHERE MaMuaGiai = 'MG001'
      AND TiSoNha IS NOT NULL
      AND TiSoKhach IS NOT NULL
)
SELECT
    clb.MaCLB,
    clb.TenCLB,
    COUNT(*) AS SoTran,
    SUM(BanThang > BanThua) AS SoTranThang,
    SUM(BanThang = BanThua) AS SoTranHoa,
    SUM(BanThang < BanThua) AS SoTranThua,
    SUM(BanThang) AS TongBanThang,
    SUM(BanThua) AS TongBanThua,
    SUM(CAST(BanThang AS SIGNED) - CAST(BanThua AS SIGNED)) AS HieuSo,
    SUM(
        CASE
            WHEN BanThang > BanThua THEN 3
            WHEN BanThang = BanThua THEN 1
            ELSE 0
        END
    ) AS Diem
FROM KetQua k
JOIN CauLacBo clb ON k.MaCLB = clb.MaCLB
GROUP BY clb.MaCLB, clb.TenCLB
ORDER BY Diem DESC, HieuSo DESC, TongBanThang DESC;


-- 10. Xác định câu lạc bộ vô địch và câu lạc bộ xuống hạng của một mùa giải
WITH KetQua AS (
    SELECT
        MaCLBNha AS MaCLB,
        TiSoNha AS BanThang,
        TiSoKhach AS BanThua
    FROM TranDau
    WHERE MaMuaGiai = 'MG001'
      AND TiSoNha IS NOT NULL
      AND TiSoKhach IS NOT NULL

    UNION ALL

    SELECT
        MaCLBKhach,
        TiSoKhach,
        TiSoNha
    FROM TranDau
    WHERE MaMuaGiai = 'MG001'
      AND TiSoNha IS NOT NULL
      AND TiSoKhach IS NOT NULL
),
BangXepHang AS (
    SELECT
        k.MaCLB,
        SUM(
            CASE
                WHEN BanThang > BanThua THEN 3
                WHEN BanThang = BanThua THEN 1
                ELSE 0
            END
        ) AS Diem,
        SUM(CAST(BanThang AS SIGNED) - CAST(BanThua AS SIGNED)) AS HieuSo,
        SUM(BanThang) AS TongBanThang
    FROM KetQua k
    GROUP BY k.MaCLB
),
XepHang AS (
    SELECT *,
        RANK() OVER (
            ORDER BY Diem DESC, HieuSo DESC, TongBanThang DESC
        ) AS HangCao,
        RANK() OVER (
            ORDER BY Diem ASC, HieuSo ASC, TongBanThang ASC
        ) AS HangThap
    FROM BangXepHang
)
SELECT
    clb.TenCLB,
    xh.Diem,
    xh.HieuSo,
    CASE
        WHEN xh.HangCao = 1 THEN 'Vô địch'
        WHEN xh.HangThap <= 3 THEN 'Xuống hạng'
    END AS KetQua
FROM XepHang xh
JOIN CauLacBo clb ON xh.MaCLB = clb.MaCLB
WHERE xh.HangCao = 1 OR xh.HangThap <= 3;


-- 11. Xếp hạng vua phá lưới và vua kiến tạo của từng mùa giải

-- Vua phá lưới
SELECT
    ct.MaCT,
    ct.HoTen,
    mg.TenMuaGiai,
    COUNT(bt.MaBT) AS SoBanThang
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
JOIN BanThang bt ON hd.MaHD = bt.MaHD
JOIN TranDau td ON bt.MaTD = td.MaTD
JOIN MuaGiai mg ON td.MaMuaGiai = mg.MaMuaGiai
WHERE bt.LoaiBanThang <> 'Phản lưới nhà'
  AND mg.MaMuaGiai = 'MG001'
GROUP BY ct.MaCT, ct.HoTen, mg.TenMuaGiai
ORDER BY SoBanThang DESC;

-- Vua kiến tạo
SELECT
    ct.MaCT,
    ct.HoTen,
    mg.TenMuaGiai,
    COUNT(bt.MaBT) AS SoLanKienTao
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
JOIN BanThang bt ON bt.MaHDKienTao = hd.MaHD
JOIN TranDau td ON bt.MaTD = td.MaTD
JOIN MuaGiai mg ON td.MaMuaGiai = mg.MaMuaGiai
WHERE mg.MaMuaGiai = 'MG001'
GROUP BY ct.MaCT, ct.HoTen, mg.TenMuaGiai
ORDER BY SoLanKienTao DESC;


-- 12. Liệt kê các cầu thủ có hợp đồng sắp hết hạn trong 6 tháng tới
SELECT
    ct.MaCT,
    ct.HoTen,
    clb.TenCLB,
    hd.NgayKy,
    hd.NgayKetThuc
FROM HopDong hd
JOIN CauThu ct ON hd.MaCT = ct.MaCT
JOIN CauLacBo clb ON hd.MaCLB = clb.MaCLB
WHERE hd.NgayKetThuc BETWEEN CURDATE()
                          AND DATE_ADD(CURDATE(), INTERVAL 6 MONTH)
ORDER BY hd.NgayKetThuc;


-- 13. Tìm cầu thủ đã ký hợp đồng với từ 3 câu lạc bộ trở lên
SELECT
    ct.MaCT,
    ct.HoTen,
    COUNT(DISTINCT hd.MaCLB) AS SoCLBDaTungThiDau
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
GROUP BY ct.MaCT, ct.HoTen
HAVING COUNT(DISTINCT hd.MaCLB) >= 3;


-- 14. Liệt kê cầu thủ bị treo giò do đủ số thẻ vàng tích lũy (ví dụ 5 thẻ vàng)
SELECT
    ct.MaCT,
    ct.HoTen,
    COUNT(tp.MaThe) AS SoTheVang
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
JOIN ThePhat tp ON hd.MaHD = tp.MaHD
JOIN TranDau td ON tp.MaTD = td.MaTD
WHERE tp.LoaiThe = 'Vàng'
  AND td.ThoiGianThiDau >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY ct.MaCT, ct.HoTen
HAVING COUNT(tp.MaThe) >= 5;


-- 15. Thống kê số thẻ phạt trung bình mỗi trận theo từng câu lạc bộ
SELECT
    clb.MaCLB,
    clb.TenCLB,
    COUNT(tp.MaThe) AS TongSoThe,
    COUNT(DISTINCT td.MaTD) AS SoTranCoThe,
    ROUND(
        COUNT(tp.MaThe) / COUNT(DISTINCT td.MaTD), 2
    ) AS SoTheTrungBinhMoiTran
FROM CauLacBo clb
JOIN HopDong hd ON clb.MaCLB = hd.MaCLB
JOIN ThePhat tp ON hd.MaHD = tp.MaHD
JOIN TranDau td ON tp.MaTD = td.MaTD
WHERE td.MaMuaGiai = 'MG001'
GROUP BY clb.MaCLB, clb.TenCLB;


-- 16. Tìm cầu thủ ghi bàn ở nhiều câu lạc bộ khác nhau trong sự nghiệp
SELECT
    ct.MaCT,
    ct.HoTen,
    COUNT(DISTINCT hd.MaCLB) AS SoCLBDaGhiBan
FROM CauThu ct
JOIN HopDong hd ON ct.MaCT = hd.MaCT
JOIN BanThang bt ON hd.MaHD = bt.MaHD
WHERE bt.LoaiBanThang <> 'Phản lưới nhà'
GROUP BY ct.MaCT, ct.HoTen
HAVING COUNT(DISTINCT hd.MaCLB) >= 2;


-- 17. Truy vấn thống kê phong độ (5 trận gần nhất, hiệu suất ghi/thua bàn, số ngày nghỉ)
-- Thay TD001 bằng mã trận đấu sắp diễn ra
SELECT
    clb.MaCLB,
    clb.TenCLB,
    tk.SoTranThang5TranGanNhat,
    tk.TrungBinhBanThang,
    tk.TrungBinhBanThua,
    tk.SoNgayNghi,
    tk.ThoiDiemTinh
FROM ThongKePhongDo tk
JOIN CauLacBo clb ON tk.MaCLB = clb.MaCLB
WHERE tk.MaTD = 'TD0001';
-- 18. Hiển thị xác suất thắng/hòa/thua mà AI đã dự đoán cho một trận đấu cụ thể, sắp xếp theo thời gian chạy dự đoán gần nhất
SELECT
    MaDuDoan,
    MaTD,
    XacSuatThangNha,
    XacSuatHoa,
    XacSuatThangKhach,
    NgayGioChayDuDoan,
    KetQuaThucTe
FROM DuDoanTranDau
WHERE MaTD = 'TD0001'
ORDER BY NgayGioChayDuDoan DESC;


-- 19. Liệt kê các trận đấu mà đội có xác suất thắng thấp hơn lại giành chiến thắng, sắp xếp theo mức chênh lệch xác suất lớn nhất
SELECT
    d.MaTD,
    d.XacSuatThangNha,
    d.XacSuatHoa,
    d.XacSuatThangKhach,
    d.KetQuaThucTe,
    CASE
        WHEN d.KetQuaThucTe = 'Thắng nhà'
            THEN d.XacSuatThangKhach - d.XacSuatThangNha
        WHEN d.KetQuaThucTe = 'Thắng khách'
            THEN d.XacSuatThangNha - d.XacSuatThangKhach
    END AS ChenhLechXacSuat
FROM DuDoanTranDau d
WHERE
    (d.KetQuaThucTe = 'Thắng nhà'
        AND d.XacSuatThangNha < d.XacSuatThangKhach)
    OR
    (d.KetQuaThucTe = 'Thắng khách'
        AND d.XacSuatThangKhach < d.XacSuatThangNha)
ORDER BY ChenhLechXacSuat DESC;


-- 20. Tính tỷ lệ dự đoán đúng của mô hình AI trong một mùa giải
SELECT
    mg.MaMuaGiai,
    mg.TenMuaGiai,
    COUNT(d.MaDuDoan) AS TongSoDuDoan,
    SUM(
        CASE
            WHEN
                (d.KetQuaThucTe = 'Thắng nhà'
                    AND d.XacSuatThangNha > d.XacSuatHoa
                    AND d.XacSuatThangNha > d.XacSuatThangKhach)
                OR
                (d.KetQuaThucTe = 'Hòa'
                    AND d.XacSuatHoa > d.XacSuatThangNha
                    AND d.XacSuatHoa > d.XacSuatThangKhach)
                OR
                (d.KetQuaThucTe = 'Thắng khách'
                    AND d.XacSuatThangKhach > d.XacSuatThangNha
                    AND d.XacSuatThangKhach > d.XacSuatHoa)
            THEN 1
            ELSE 0
        END
    ) AS SoDuDoanDung,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN
                    (d.KetQuaThucTe = 'Thắng nhà'
                        AND d.XacSuatThangNha > d.XacSuatHoa
                        AND d.XacSuatThangNha > d.XacSuatThangKhach)
                    OR
                    (d.KetQuaThucTe = 'Hòa'
                        AND d.XacSuatHoa > d.XacSuatThangNha
                        AND d.XacSuatHoa > d.XacSuatThangKhach)
                    OR
                    (d.KetQuaThucTe = 'Thắng khách'
                        AND d.XacSuatThangKhach > d.XacSuatThangNha
                        AND d.XacSuatThangKhach > d.XacSuatHoa)
                THEN 1
                ELSE 0
            END
        ) / COUNT(d.MaDuDoan),
        2
    ) AS TyLeDuDoanDung
FROM MuaGiai mg
JOIN TranDau td ON td.MaMuaGiai = mg.MaMuaGiai
JOIN DuDoanTranDau d ON d.MaTD = td.MaTD
WHERE mg.MaMuaGiai = 'MG001'
    AND d.KetQuaThucTe IS NOT NULL
GROUP BY mg.MaMuaGiai, mg.TenMuaGiai;
