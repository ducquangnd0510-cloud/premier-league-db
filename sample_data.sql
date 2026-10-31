-- ================= DỮ LIỆU MẪU =================
INSERT INTO CauLacBo (TenCLB, SanNha, ThanhPho, NamThanhLap) VALUES
('Arsenal','Emirates','London',1886),('Man City','Etihad','Manchester',1880),
('Liverpool','Anfield','Liverpool',1892),('Chelsea','Stamford Bridge','London',1905),
('Man United','Old Trafford','Manchester',1878),('Tottenham','Tottenham Hotspur Stadium','London',1882);

INSERT INTO CauThu (HoTen, NgaySinh, QuocTich, ViTri) VALUES
('Bukayo Saka','2001-09-05','Anh','Tiền vệ'),('Erling Haaland','2000-07-21','Na Uy','Tiền đạo'),
('Mohamed Salah','1992-06-15','Ai Cập','Tiền đạo'),('Cole Palmer','2002-05-06','Anh','Tiền vệ'),
('Bruno Fernandes','1994-09-08','Bồ Đào Nha','Tiền vệ'),('Son Heung-min','1992-07-08','Hàn Quốc','Tiền đạo'),
('William Saliba','2001-03-24','Pháp','Hậu vệ'),('David Raya','1995-09-15','Tây Ban Nha','Thủ môn'),
('Rodri','1996-06-22','Tây Ban Nha','Tiền vệ'),('Virgil van Dijk','1991-07-08','Hà Lan','Hậu vệ');

-- Hợp đồng i thuộc cầu thủ i
INSERT INTO HopDong (MaCauThu, MaCLB, NgayBatDau, NgayKetThuc) VALUES
(1,1,'2024-07-01','2027-06-30'),(2,2,'2024-07-01','2034-06-30'),(3,3,'2024-07-01','2027-06-30'),
(4,4,'2024-07-01','2033-06-30'),(5,5,'2024-07-01','2027-06-30'),(6,6,'2024-07-01','2026-12-31'),
(7,1,'2024-07-01','2027-06-30'),(8,1,'2024-07-01','2027-06-30'),(9,2,'2024-07-01','2027-06-30'),
(10,3,'2024-07-01','2027-06-30');

INSERT INTO HuanLuyenVien (HoTen, QuocTich) VALUES
('Mikel Arteta','Tây Ban Nha'),('Pep Guardiola','Tây Ban Nha'),('Arne Slot','Hà Lan'),
('Enzo Maresca','Ý'),('Ruben Amorim','Bồ Đào Nha'),('Thomas Frank','Đan Mạch');
INSERT INTO BoNhiemHLV (MaHLV, MaCLB, NgayBoNhiem, NgayKetThuc) VALUES
(1,1,'2019-12-20',NULL),(2,2,'2016-07-01',NULL),(3,3,'2024-06-01',NULL),
(4,4,'2024-06-03',NULL),(5,5,'2024-11-11',NULL),(6,6,'2025-06-12',NULL);

INSERT INTO MuaGiai (TenMuaGiai, NgayBatDau, NgayKetThuc) VALUES ('2026-2027','2026-08-01','2027-05-31');

INSERT INTO TranDau (MaMuaGiai, MaCLBNha, MaCLBKhach, VongDau, ThoiGian, SanVanDong, TySoNha, TySoKhach) VALUES
(1,1,5,1,'2026-08-15 18:30:00','Emirates',2,0),
(1,2,6,1,'2026-08-15 21:00:00','Etihad',3,1),
(1,3,4,1,'2026-08-16 20:00:00','Anfield',1,1),
(1,4,1,2,'2026-08-22 18:30:00','Stamford Bridge',0,2),
(1,5,2,2,'2026-08-22 21:00:00','Old Trafford',1,3),
(1,6,3,2,'2026-08-23 20:00:00','Tottenham Hotspur Stadium',2,2),
(1,1,2,3,'2026-08-29 18:30:00','Emirates',1,1),
(1,3,5,3,'2026-08-29 21:00:00','Anfield',4,0),
(1,4,6,3,'2026-08-30 20:00:00','Stamford Bridge',2,1),
(1,2,3,4,'2026-09-12 18:30:00','Etihad',2,1),
(1,6,1,4,'2026-09-12 21:00:00','Tottenham Hotspur Stadium',0,1),
(1,5,4,4,'2026-09-13 20:00:00','Old Trafford',1,1),
(1,1,3,5,'2026-11-07 18:30:00','Emirates',NULL,NULL),
(1,2,4,5,'2026-11-07 21:00:00','Etihad',NULL,NULL),
(1,5,6,5,'2026-11-08 20:00:00','Old Trafford',NULL,NULL);

-- (trận, hợp đồng ghi bàn, phút, loại, hợp đồng kiến tạo)
INSERT INTO BanThang (MaTranDau, MaHopDong, PhutGhiBan, LoaiBanThang, MaHopDongKienTao) VALUES
(1,1,23,'Thường',7),(1,7,67,'Thường',1),
(2,2,12,'Thường',9),(2,2,45,'Penalty',NULL),(2,9,78,'Thường',2),(2,6,60,'Thường',NULL),
(3,3,30,'Thường',10),(3,4,81,'Thường',NULL),
(4,1,15,'Thường',7),(4,1,70,'Thường',NULL),
(5,5,40,'Thường',NULL),(5,2,10,'Thường',9),(5,2,55,'Thường',9),(5,9,88,'Thường',2),
(6,6,20,'Thường',NULL),(6,6,66,'Penalty',NULL),(6,3,35,'Thường',10),(6,3,90,'Thường',NULL),
(7,1,50,'Thường',7),(7,2,75,'Thường',9),
(8,3,8,'Thường',10),(8,3,33,'Thường',10),(8,10,60,'Thường',3),(8,3,85,'Penalty',NULL),
(9,4,25,'Thường',NULL),(9,4,72,'Thường',NULL),(9,6,44,'Thường',NULL),
(10,2,18,'Thường',9),(10,2,64,'Thường',9),(10,3,89,'Thường',10),
(11,1,52,'Thường',7),
(12,5,31,'Thường',NULL),(12,4,77,'Thường',NULL);

INSERT INTO ThePhat (MaTranDau, MaHopDong, PhutNhanThe, LoaiThe) VALUES
(2,6,70,'Vàng'),(5,5,62,'Vàng'),(11,6,80,'Đỏ');
