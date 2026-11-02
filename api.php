<?php
// API trả dữ liệu JSON cho trang web (MySQL + PDO) - CSDL QuanLyNgoaiHangAnh
// Gọi: api.php            -> mùa giải đang diễn ra (hoặc mới nhất)
//      api.php?mua=MG001  -> mùa giải chỉ định
header('Content-Type: application/json; charset=utf-8');

// ====== CẤU HÌNH CSDL (sửa cho khớp máy của bạn) ======
$DB = ['host' => 'localhost', 'name' => 'QuanLyNgoaiHangAnh', 'user' => 'root', 'pass' => ''];

// Gộp các dòng (MaCT, MaCLB, n) thành mỗi cầu thủ một dòng: tổng n + danh sách CLB theo thứ tự hợp đồng
function gopTheoCauThu(array $rows, int $min = 1, int $limit = 0): array {
    $m = [];
    foreach ($rows as $r) {
        $k = $r['MaCT'];
        if (!isset($m[$k])) $m[$k] = ['ten' => $r['HoTen'], 'clb' => [], 'n' => 0, 'do' => 0];
        $m[$k]['n'] += (int)$r['n'];
        $m[$k]['do'] += (int)($r['nd'] ?? 0);
        $m[$k]['clb'][] = $r['MaCLB'];
    }
    $m = array_values(array_filter($m, fn($x) => $x['n'] >= $min));
    usort($m, fn($a, $b) => $b['n'] <=> $a['n'] ?: strcmp($a['ten'], $b['ten']));
    return $limit > 0 ? array_slice($m, 0, $limit) : $m;
}

try {
    $pdo = new PDO(
        "mysql:host={$DB['host']};dbname={$DB['name']};charset=utf8mb4",
        $DB['user'], $DB['pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );

    // Danh sách mùa giải (cho ô chọn mùa)
    $muas = $pdo->query("SELECT MaMuaGiai AS id, TenMuaGiai AS ten FROM MuaGiai ORDER BY ThoiGianBatDau")->fetchAll();

    // Mùa giải: ?mua=MG001, mặc định là mùa đang diễn ra, nếu không có thì mùa mới nhất
    $maMua = $_GET['mua'] ?? '';
    if ($maMua === '') {
        $maMua = (string)$pdo->query(
            "SELECT MaMuaGiai FROM MuaGiai
             ORDER BY (CURDATE() BETWEEN ThoiGianBatDau AND ThoiGianKetThuc) DESC, ThoiGianBatDau DESC LIMIT 1"
        )->fetchColumn();
    }
    $st = $pdo->prepare("SELECT MaMuaGiai AS id, TenMuaGiai AS ten FROM MuaGiai WHERE MaMuaGiai = ?");
    $st->execute([$maMua]);
    $mua = $st->fetch();
    if (!$mua) { http_response_code(404); echo json_encode(['error' => 'Không tìm thấy mùa giải'], JSON_UNESCAPED_UNICODE); exit; }

    // 1. CLB + HLV đang tại nhiệm (NgayKetThuc IS NULL) + các HLV tiền nhiệm
    $clubs = $pdo->query(
        "SELECT c.MaCLB AS id, c.TenCLB AS ten, c.SanNha AS san, c.ThanhPho AS tp,
                c.NamThanhLap AS nam, h.HoTen AS hlv
         FROM CauLacBo c
         LEFT JOIN BoNhiemHLV b ON b.MaCLB = c.MaCLB AND b.NgayKetThuc IS NULL
         LEFT JOIN HuanLuyenVien h ON h.MaHLV = b.MaHLV
         ORDER BY c.MaCLB"
    )->fetchAll();
    $cu = [];
    foreach ($pdo->query(
        "SELECT b.MaCLB, h.HoTen, YEAR(b.NgayBoNhiem) AS tu, YEAR(b.NgayKetThuc) AS den
         FROM BoNhiemHLV b JOIN HuanLuyenVien h ON h.MaHLV = b.MaHLV
         WHERE b.NgayKetThuc IS NOT NULL ORDER BY b.NgayKetThuc DESC"
    )->fetchAll() as $r) {
        $cu[$r['MaCLB']][] = ['ten' => $r['HoTen'], 'tu' => (int)$r['tu'], 'den' => (int)$r['den']];
    }
    foreach ($clubs as &$c) { $c['nam'] = (int)$c['nam']; $c['hlv'] = $c['hlv'] ?? '—'; $c['cu'] = $cu[$c['id']] ?? []; }
    unset($c);

    // 2. Lịch sử hợp đồng của từng cầu thủ (qua các kỳ chuyển nhượng)
    $ls = [];
    foreach ($pdo->query(
        "SELECT MaCT, MaCLB, YEAR(NgayKy) AS tu, NgayKetThuc FROM HopDong ORDER BY MaCT, NgayKy"
    )->fetchAll() as $r) {
        $ls[$r['MaCT']][] = [$r['MaCLB'], (int)$r['tu'], $r['NgayKetThuc']];
    }

    // 3. Cầu thủ: CLB hiện tại = hợp đồng đang hiệu lực hôm nay (nếu không có thì hợp đồng kết thúc muộn nhất)
    $players = $pdo->query(
        "SELECT ct.MaCT AS id, ct.HoTen AS ten, ct.QuocTich AS qt, ct.ViTri AS vt, hd.MaCLB AS clb,
                ct.NgaySinh AS sn, hd.NgayKetThuc AS hh
         FROM CauThu ct
         JOIN HopDong hd ON hd.MaHD = (
               SELECT h3.MaHD FROM HopDong h3 WHERE h3.MaCT = ct.MaCT
               ORDER BY (CURDATE() BETWEEN h3.NgayKy AND h3.NgayKetThuc) DESC, h3.NgayKetThuc DESC LIMIT 1)
         ORDER BY ct.MaCT"
    )->fetchAll();
    foreach ($players as &$p) { $p['ls'] = $ls[$p['id']] ?? []; }
    unset($p);

    // 4. Vua phá lưới / vua kiến tạo / thẻ phạt của mùa giải (tính theo CLB lúc ghi bàn, không tính phản lưới)
    $st = $pdo->prepare(
        "SELECT h.MaCT, ct.HoTen, h.MaCLB, COUNT(*) AS n
         FROM BanThang b
         JOIN HopDong h ON h.MaHD = b.MaHD
         JOIN CauThu ct ON ct.MaCT = h.MaCT
         JOIN TranDau t ON t.MaTD = b.MaTD
         WHERE t.MaMuaGiai = ? AND b.LoaiBanThang <> 'Phản lưới nhà'
         GROUP BY h.MaCT, ct.HoTen, h.MaCLB ORDER BY h.MaCT, MIN(h.NgayKy)"
    );
    $st->execute([$maMua]);
    $banThang = gopTheoCauThu($st->fetchAll(), 1, 10);

    $st = $pdo->prepare(
        "SELECT h.MaCT, ct.HoTen, h.MaCLB, COUNT(*) AS n
         FROM BanThang b
         JOIN HopDong h ON h.MaHD = b.MaHDKienTao
         JOIN CauThu ct ON ct.MaCT = h.MaCT
         JOIN TranDau t ON t.MaTD = b.MaTD
         WHERE t.MaMuaGiai = ?
         GROUP BY h.MaCT, ct.HoTen, h.MaCLB ORDER BY h.MaCT, MIN(h.NgayKy)"
    );
    $st->execute([$maMua]);
    $kienTao = gopTheoCauThu($st->fetchAll(), 1, 10);

    $st = $pdo->prepare(
        "SELECT h.MaCT, ct.HoTen, h.MaCLB, SUM(tp.LoaiThe = 'Vàng') AS n, SUM(tp.LoaiThe = 'Đỏ') AS nd
         FROM ThePhat tp
         JOIN HopDong h ON h.MaHD = tp.MaHD
         JOIN CauThu ct ON ct.MaCT = h.MaCT
         JOIN TranDau t ON t.MaTD = tp.MaTD
         WHERE t.MaMuaGiai = ?
         GROUP BY h.MaCT, ct.HoTen, h.MaCLB ORDER BY h.MaCT, MIN(h.NgayKy)"
    );
    $st->execute([$maMua]);
    $theVang = gopTheoCauThu($st->fetchAll(), 5, 10);   // từ 5 thẻ vàng trở lên (ngưỡng treo giò)
    $top = ['ban' => $banThang, 'kt' => $kienTao, 'the' => $theVang];

    // 5. Trận đấu của mùa giải: [vòng, mã nhà, mã khách, tỷ số nhà, tỷ số khách, ngày giờ]
    $st = $pdo->prepare(
        "SELECT VongDau, MaCLBNha, MaCLBKhach, TiSoNha, TiSoKhach, DATE_FORMAT(ThoiGianThiDau, '%Y-%m-%d %H:%i')
         FROM TranDau WHERE MaMuaGiai = ? ORDER BY ThoiGianThiDau, MaTD"
    );
    $st->execute([$maMua]);
    $matches = array_map(fn($r) => [
        (int)$r[0], $r[1], $r[2],
        $r[3] === null ? null : (int)$r[3],
        $r[4] === null ? null : (int)$r[4],
        $r[5]
    ], $st->fetchAll(PDO::FETCH_NUM));

    // 6. Dự đoán mới nhất + thống kê phong độ hai đội của từng trận (cùng thứ tự với $matches)
    //    p = null nếu trận chưa có dự đoán; th/tk = null nếu chưa tính được phong độ
    $st = $pdo->prepare(
        "SELECT d.XacSuatThangNha, d.XacSuatHoa, d.XacSuatThangKhach,
                (SELECT COUNT(*) FROM DuDoanTranDau WHERE MaTD = t.MaTD) AS luot,
                kn.SoTranThang5TranGanNhat, kn.TrungBinhBanThang, kn.TrungBinhBanThua, kn.SoNgayNghi,
                kk.SoTranThang5TranGanNhat, kk.TrungBinhBanThang, kk.TrungBinhBanThua, kk.SoNgayNghi,
                t.SanVanDong, o.MaCLB
         FROM TranDau t
         LEFT JOIN DuDoanTranDau d ON d.MaTD = t.MaTD
          AND d.NgayGioChayDuDoan = (SELECT MAX(NgayGioChayDuDoan) FROM DuDoanTranDau WHERE MaTD = t.MaTD)
         LEFT JOIN ThongKePhongDo kn ON kn.MaTD = t.MaTD AND kn.MaCLB = t.MaCLBNha
         LEFT JOIN ThongKePhongDo kk ON kk.MaTD = t.MaTD AND kk.MaCLB = t.MaCLBKhach
         LEFT JOIN CauLacBo o ON o.SanNha = t.SanVanDong
         WHERE t.MaMuaGiai = ? ORDER BY t.ThoiGianThiDau, t.MaTD"
    );
    $st->execute([$maMua]);
    $form = fn($r, $o) => $r[$o] === null ? null
        : ['w' => (int)$r[$o], 'gf' => (float)$r[$o + 1], 'ga' => (float)$r[$o + 2], 'nghi' => (int)$r[$o + 3]];
    $preds = array_map(fn($r) => [
        'p'  => $r[0] === null ? null : [(float)$r[0], (float)$r[1], (float)$r[2]],
        'n'  => (int)$r[3],
        'th' => $form($r, 4),
        'tk' => $form($r, 8),
        'san' => $r[12],
        'chu' => $r[13],
    ], $st->fetchAll(PDO::FETCH_NUM));

    // 7. Thông tin mô hình AI (bảng MoHinhAI do ai_model.sql tạo; chưa cài thì bỏ qua)
    $model = null;
    try {
        $r = $pdo->query("SELECT TenMoHinh, SoMauHuanLuyen, DoChinhXacCV, DATE(ThoiDiemHuanLuyen) FROM MoHinhAI LIMIT 1")->fetch(PDO::FETCH_NUM);
        if ($r) $model = ['ten' => $r[0], 'mau' => (int)$r[1], 'cv' => $r[2] === null ? null : (float)$r[2], 'ngay' => $r[3]];
    } catch (Throwable $e) { /* chưa có mô hình AI */ }

    echo json_encode(compact('mua', 'muas', 'clubs', 'players', 'top', 'matches', 'preds', 'model'), JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    error_log('api.php: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Lỗi máy chủ khi truy vấn dữ liệu'], JSON_UNESCAPED_UNICODE);
}
