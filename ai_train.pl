#!/usr/bin/perl
# ai_train.pl : huấn luyện mô hình softmax (hồi quy logistic đa lớp) cho dự đoán kết quả trận đấu.
#
# Đặc trưng lấy từ view vw_DacTrungDuDoan (tạo bởi ai_model.sql) => khớp 100% với lúc dự đoán.
# Kết quả: file ai_weights.sql (REPLACE INTO MoHinhAI ...) + báo cáo độ chính xác.
#
# Cách chạy (Git Bash / MSYS2 / Linux đều có sẵn perl):
#   MYSQL_ARGS="-uroot -pMATKHAU" perl ai_train.pl
#   MYSQL_EXE="/c/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" MYSQL_ARGS="-uroot -pMATKHAU" perl ai_train.pl
#   perl ai_train.pl --tsv dactrung.tsv        # hoặc đọc từ file TSV đã xuất sẵn
# Sau đó nạp trọng số mới:  mysql -u root -p < ai_weights.sql
use strict; use warnings;

my $tsv; my $out = 'ai_weights.sql'; my $db = 'QuanLyNgoaiHangAnh';
while (@ARGV) { my $a = shift; if ($a eq '--tsv') { $tsv = shift } elsif ($a eq '--out') { $out = shift } elsif ($a eq '--db') { $db = shift } }

# ---------- đọc dữ liệu ----------
my $sql = "SELECT MaTD,MaMuaGiai,ChenhPPG,ChenhHieuSo,ChenhPhongDo5,ChenhGD5,ChenhNghi,IFNULL(KetQua,'-') "
        . "FROM vw_DacTrungDuDoan ORDER BY ThoiGianThiDau,MaTD";
my @lines;
if ($tsv) { open my $f, '<:raw', $tsv or die "Không mở được $tsv: $!"; @lines = <$f>; close $f; }
else {
    my $exe = $ENV{MYSQL_EXE} // 'mysql'; my $args = $ENV{MYSQL_ARGS} // '-uroot';
    open my $f, '-|', qq{"$exe" $args --default-character-set=utf8mb4 -B -N --raw $db -e "$sql"} or die "Không chạy được mysql: $!";
    @lines = <$f>; close $f;
}
my @CLS = ('Thắng nhà', 'Hòa', 'Thắng khách'); my %CI = map { $CLS[$_] => $_ } 0..2;
my @data;   # {mua, x=[1,f1..f5], y}
for (@lines) { s/\r?\n$//; my @c = split /\t/; next unless @c == 8 && exists $CI{$c[7]};
    push @data, { mua => $c[1], x => [1, @c[2..6]], y => $CI{$c[7]} }; }
die "Không có dữ liệu huấn luyện (đã chạy ai_model.sql và nạp dữ liệu chưa?)\n" unless @data;
printf "Số trận đã đá có đặc trưng: %d  (nhà thắng %d, hòa %d, khách thắng %d)\n", scalar @data,
    (scalar grep { $_->{y} == 0 } @data), (scalar grep { $_->{y} == 1 } @data), (scalar grep { $_->{y} == 2 } @data);

# ---------- softmax regression ----------
sub softmax { my ($W, $x) = @_; my @z = map { my $w = $_; my $s = 0; $s += $w->[$_] * $x->[$_] for 0..5; $s } @$W;
    my $m = $z[0]; for (@z) { $m = $_ if $_ > $m } my @e = map { exp($_ - $m) } @z; my $t = 0; $t += $_ for @e; [ map { $_ / $t } @e ] }
sub train { my ($set, $lam) = @_; my $n = @$set; my @W = map { [ (0) x 6 ] } 0..2; my $lr = 0.8;
    for my $it (1..1500) {
        my @G = map { [ (0) x 6 ] } 0..2;
        for my $d (@$set) { my $p = softmax(\@W, $d->{x});
            for my $k (0..2) { my $e = $p->[$k] - ($d->{y} == $k ? 1 : 0); $G[$k][$_] += $e * $d->{x}[$_] for 0..5; } }
        for my $k (0..2) { for my $j (0..5) { my $g = $G[$k][$j] / $n + ($j ? $lam * $W[$k][$j] : 0); $W[$k][$j] -= $lr * $g; } } }
    \@W }
sub predict { my ($W, $x) = @_; my $p = softmax($W, $x); my $b = 0; for (1..2) { $b = $_ if $p->[$_] > $p->[$b] } $b }
sub acc { my ($W, $set) = @_; return 0 unless @$set; my $ok = 0; $ok++ for grep { predict($W, $_->{x}) == $_->{y} } @$set; 100 * $ok / @$set }
sub cv { my ($set, $lam, $k) = @_; my @idx = (0..$#$set); srand(7); for (my $i = $#idx; $i > 0; $i--) { my $j = int(rand($i + 1)); @idx[$i, $j] = @idx[$j, $i] }
    my $ok = 0; for my $f (0..$k-1) { my (@tr, @te); for my $p (0..$#idx) { push @{ $p % $k == $f ? \@te : \@tr }, $set->[$idx[$p]] }
        my $W = train(\@tr, $lam); $ok += grep { predict($W, $_->{x}) == $_->{y} } @te; } 100 * $ok / @$set }

# ---------- chọn lambda bằng kiểm tra chéo trên mùa đầu, đánh giá hold-out trên mùa sau ----------
my @mua = do { my %s; grep { !$s{$_}++ } map { $_->{mua} } @data }; # theo thứ tự thời gian
my @first = grep { $_->{mua} eq $mua[0] } @data; my @rest = grep { $_->{mua} ne $mua[0] } @data;
my ($bestL, $bestA) = (0.03, -1);
if (@first >= 100) { for my $l (0.003, 0.03, 0.3) { my $a = cv(\@first, $l, 5); printf "  lambda=%-6s CV 5-fold trên %s: %.1f%%\n", $l, $mua[0], $a; if ($a > $bestA) { ($bestA, $bestL) = ($a, $l) } } }
print "=> chọn lambda = $bestL\n";
my $home = 100 * (scalar grep { $_->{y} == 0 } @data) / @data;
if (@first >= 100 && @rest) { my $W = train(\@first, $bestL);
    printf "Hold-out: huấn luyện trên %s (%d trận) -> kiểm tra trên các mùa sau (%d trận): %.1f%%  (luôn đoán 'thắng nhà': %.1f%%)\n",
        $mua[0], scalar @first, scalar @rest, acc($W, \@rest), 100 * (scalar grep { $_->{y} == 0 } @rest) / @rest; }
my $cvall = cv(\@data, $bestL, 5);
printf "Kiểm tra chéo 5-fold trên toàn bộ %d trận: %.1f%%  (luôn đoán 'thắng nhà': %.1f%%)\n", scalar @data, $cvall, $home;

# ---------- huấn luyện lần cuối trên toàn bộ + ghi trọng số ----------
my $W = train(\@data, $bestL);
printf "Mô hình cuối (huấn luyện trên toàn bộ): độ chính xác trên chính tập huấn luyện: %.1f%%\n", acc($W, \@data);
my @names = qw(HeSoTuDo W_ChenhPPG W_ChenhHieuSo W_ChenhPhongDo5 W_ChenhGD5 W_ChenhNghi);
open my $o, '>:raw', $out or die; print $o "-- Trọng số mô hình AI (sinh bởi ai_train.pl)\nUSE $db;\n";
for my $k (0..2) { printf $o "REPLACE INTO MoHinhAI (Lop,%s,TenMoHinh,SoMauHuanLuyen,DoChinhXacCV,ThoiDiemHuanLuyen) VALUES ('%s',%s,'Hồi quy logistic đa lớp (softmax)',%d,%.2f,NOW());\n",
    join(',', @names), $CLS[$k], join(',', map { sprintf '%.8f', $_ } @{ $W->[$k] }), scalar @data, $cvall; }
close $o; print "Đã ghi $out\n";
