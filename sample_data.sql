USE QuanLyNgoaiHangAnh;

-- CLB
INSERT INTO CauLacBo VALUES
('CLB001','Arsenal','Emirates','London',1886),
('CLB002','Man City','Etihad','Manchester',1880),
('CLB003','Liverpool','Anfield','Liverpool',1892),
('CLB004','Chelsea','Stamford Bridge','London',1905),
('CLB005','Man United','Old Trafford','Manchester',1878),
('CLB006','Tottenham','Tottenham Hotspur Stadium','London',1882);

-- CẦU THỦ
INSERT INTO CauThu VALUES
('CT001','Bukayo Saka','2001-09-05','Anh','Tiền vệ'),
('CT002','Erling Haaland','2000-07-21','Na Uy','Tiền đạo'),
('CT003','Mohamed Salah','1992-06-15','Ai Cập','Tiền đạo'),
('CT004','Cole Palmer','2002-05-06','Anh','Tiền vệ'),
('CT005','Bruno Fernandes','1994-09-08','Bồ Đào Nha','Tiền vệ'),
('CT006','Son Heung-min','1992-07-08','Hàn Quốc','Tiền đạo'),
('CT007','William Saliba','2001-03-24','Pháp','Hậu vệ'),
('CT008','David Raya','1995-09-15','Tây Ban Nha','Thủ môn'),
('CT009','Rodri','1996-06-22','Tây Ban Nha','Tiền vệ'),
('CT010','Virgil van Dijk','1991-07-08','Hà Lan','Hậu vệ');

-- HỢP ĐỒNG
INSERT INTO HopDong VALUES
('HD001','CT001','CLB001','2024-07-01','2027-06-30'),
('HD002','CT002','CLB002','2024-07-01','2034-06-30'),
('HD003','CT003','CLB003','2024-07-01','2027-06-30'),
('HD004','CT004','CLB004','2024-07-01','2033-06-30'),
('HD005','CT005','CLB005','2024-07-01','2027-06-30'),
('HD006','CT006','CLB006','2024-07-01','2026-12-31'),
('HD007','CT007','CLB001','2024-07-01','2027-06-30'),
('HD008','CT008','CLB001','2024-07-01','2027-06-30'),
('HD009','CT009','CLB002','2024-07-01','2027-06-30'),
('HD010','CT010','CLB003','2024-07-01','2027-06-30');

-- HUẤN LUYỆN VIÊN
INSERT INTO HuanLuyenVien VALUES
('HLV001','Mikel Arteta','Tây Ban Nha'),
('HLV002','Pep Guardiola','Tây Ban Nha'),
('HLV003','Arne Slot','Hà Lan'),
('HLV004','Enzo Maresca','Ý'),
('HLV005','Ruben Amorim','Bồ Đào Nha'),
('HLV006','Thomas Frank','Đan Mạch');

-- BỔ NHIỆM HLV
INSERT INTO BoNhiemHLV VALUES
('BN001','HLV001','CLB001','2019-12-20',NULL),
('BN002','HLV002','CLB002','2016-07-01',NULL),
('BN003','HLV003','CLB003','2024-06-01',NULL),
('BN004','HLV004','CLB004','2024-06-03',NULL),
('BN005','HLV005','CLB005','2024-11-11',NULL),
('BN006','HLV006','CLB006','2025-06-12',NULL);

-- MÙA GIẢI
INSERT INTO MuaGiai VALUES
('MG001','2026-2027','2026-08-01','2027-05-31');

-- TRẬN ĐẤU
INSERT INTO TranDau VALUES
('TD001','MG001','CLB001','CLB005',1,'2026-08-15 18:30:00','Emirates',2,0),
('TD002','MG001','CLB002','CLB006',1,'2026-08-15 21:00:00','Etihad',3,1),
('TD003','MG001','CLB003','CLB004',1,'2026-08-16 20:00:00','Anfield',1,1),
('TD004','MG001','CLB004','CLB001',2,'2026-08-22 18:30:00','Stamford Bridge',0,2),
('TD005','MG001','CLB005','CLB002',2,'2026-08-22 21:00:00','Old Trafford',1,3),
('TD006','MG001','CLB006','CLB003',2,'2026-08-23 20:00:00','Tottenham Hotspur Stadium',2,2),
('TD007','MG001','CLB001','CLB002',3,'2026-08-29 18:30:00','Emirates',1,1),
('TD008','MG001','CLB003','CLB005',3,'2026-08-29 21:00:00','Anfield',4,0),
('TD009','MG001','CLB004','CLB006',3,'2026-08-30 20:00:00','Stamford Bridge',2,1),
('TD010','MG001','CLB002','CLB003',4,'2026-09-12 18:30:00','Etihad',2,1),
('TD011','MG001','CLB006','CLB001',4,'2026-09-12 21:00:00','Tottenham Hotspur Stadium',0,1),
('TD012','MG001','CLB005','CLB004',4,'2026-09-13 20:00:00','Old Trafford',1,1),
('TD013','MG001','CLB001','CLB003',5,'2026-11-07 18:30:00','Emirates',NULL,NULL),
('TD014','MG001','CLB002','CLB004',5,'2026-11-07 21:00:00','Etihad',NULL,NULL),
('TD015','MG001','CLB005','CLB006',5,'2026-11-08 20:00:00','Old Trafford',NULL,NULL);

-- BÀN THẮNG
INSERT INTO BanThang VALUES
('BT001','TD001','HD001',23,'Thường','HD007'),
('BT002','TD001','HD007',67,'Thường','HD001'),
('BT003','TD002','HD002',12,'Thường','HD009'),
('BT004','TD002','HD002',45,'Penalty',NULL),
('BT005','TD002','HD009',78,'Thường','HD002'),
('BT006','TD002','HD006',60,'Thường',NULL),
('BT007','TD003','HD003',30,'Thường','HD010'),
('BT008','TD003','HD004',81,'Thường',NULL),
('BT009','TD004','HD001',15,'Thường','HD007'),
('BT010','TD004','HD001',70,'Thường',NULL),
('BT011','TD005','HD005',40,'Thường',NULL),
('BT012','TD005','HD002',10,'Thường','HD009'),
('BT013','TD005','HD002',55,'Thường','HD009'),
('BT014','TD005','HD009',88,'Thường','HD002'),
('BT015','TD006','HD006',20,'Thường',NULL),
('BT016','TD006','HD006',66,'Penalty',NULL),
('BT017','TD006','HD003',35,'Thường','HD010'),
('BT018','TD006','HD003',90,'Thường',NULL),
('BT019','TD007','HD001',50,'Thường','HD007'),
('BT020','TD007','HD002',75,'Thường','HD009'),
('BT021','TD008','HD003',8,'Thường','HD010'),
('BT022','TD008','HD003',33,'Thường','HD010'),
('BT023','TD008','HD010',60,'Thường','HD003'),
('BT024','TD008','HD003',85,'Penalty',NULL),
('BT025','TD009','HD004',25,'Thường',NULL),
('BT026','TD009','HD004',72,'Thường',NULL),
('BT027','TD009','HD006',44,'Thường',NULL),
('BT028','TD010','HD002',18,'Thường','HD009'),
('BT029','TD010','HD002',64,'Thường','HD009'),
('BT030','TD010','HD003',89,'Thường','HD010'),
('BT031','TD011','HD001',52,'Thường','HD007'),
('BT032','TD012','HD005',31,'Thường',NULL),
('BT033','TD012','HD004',77,'Thường',NULL);

-- THẺ PHẠT
INSERT INTO ThePhat VALUES
('TP001','TD002','HD006',70,'Vàng'),
('TP002','TD005','HD005',62,'Vàng'),
('TP003','TD011','HD006',80,'Đỏ');
