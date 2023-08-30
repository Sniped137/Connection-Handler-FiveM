-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               10.4.28-MariaDB - mariadb.org binary distribution
-- Server OS:                    Win64
-- HeidiSQL Version:             12.5.0.6677
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for core
CREATE DATABASE IF NOT EXISTS `core` /*!40100 DEFAULT CHARACTER SET latin1 COLLATE latin1_bin */;
USE `core`;

-- Dumping structure for table core.user_identifiers
CREATE TABLE IF NOT EXISTS `user_identifiers` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `steam_id` varchar(50) DEFAULT NULL,
  `ip` varchar(200) DEFAULT NULL,
  `license` varchar(200) DEFAULT NULL,
  `discord` varchar(200) DEFAULT NULL,
  `xbl` varchar(200) DEFAULT NULL,
  `liveid` varchar(200) DEFAULT NULL,
  `tokens` varchar(10000) DEFAULT NULL,
  `lastKnownName` varchar(200) DEFAULT NULL,
  `isBanned` tinyint(1) DEFAULT 0,
  `banReason` text DEFAULT '',
  `bannedBy` text DEFAULT '',
  `banExpires` bigint(200) DEFAULT 0,
  `timeModified` datetime DEFAULT current_timestamp(),
  `timeCreated` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=247 DEFAULT CHARSET=latin1 COLLATE=latin1_bin;

-- Dumping data for table core.user_identifiers: ~1 rows (approximately)
INSERT INTO `user_identifiers` (`id`, `steam_id`, `ip`, `license`, `discord`, `xbl`, `liveid`, `tokens`, `lastKnownName`, `isBanned`, `banReason`, `bannedBy`, `banExpires`, `timeModified`, `timeCreated`) VALUES
	(1, 'Example Steam ID Here', 'Example IP here', 'example license here', 'example license here', 'example license here', 'example license here', 'example token list here', 'Example Name', 0, '', '', 0, '2023-06-15 01:20:33', '2023-06-15 01:20:33');

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
