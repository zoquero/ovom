-- phpMyAdmin SQL Dump
-- version 4.5.4.1deb2ubuntu2
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Aug 09, 2017 at 08:05 PM
-- Server version: 5.7.19-0ubuntu0.16.04.1
-- PHP Version: 7.0.18-0ubuntu0.16.04.1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `ovomdb`
--

-- --------------------------------------------------------

--
-- Table structure for table `cluster`
--

CREATE TABLE `cluster` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `moref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `datacenter`
--

CREATE TABLE `datacenter` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `moref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL,
  `datastore_folder` int(10) UNSIGNED NOT NULL,
  `vm_folder` int(10) UNSIGNED NOT NULL,
  `host_folder` int(10) UNSIGNED NOT NULL,
  `network_folder` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `folder`
--

CREATE TABLE `folder` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `moref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT '0' COMMENT '1 enabled, 0 disabled'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `host`
--

CREATE TABLE `host` (
  `id` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `moref` varchar(255) NOT NULL,
  `parent` int(11) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `virtualmachine`
--

CREATE TABLE `virtualmachine` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `moref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `cluster`
--
ALTER TABLE `cluster`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `moref_uniq` (`moref`),
  ADD KEY `parent_idx` (`parent`);

--
-- Indexes for table `datacenter`
--
ALTER TABLE `datacenter`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `moref_uniq` (`moref`),
  ADD KEY `parent_idx` (`parent`),
  ADD KEY `moref_idx` (`moref`),
  ADD KEY `folder_idx` (`datastore_folder`),
  ADD KEY `vm_folder_idx` (`vm_folder`),
  ADD KEY `host_folder_idx` (`host_folder`),
  ADD KEY `network_folder_idx` (`network_folder`);

--
-- Indexes for table `folder`
--
ALTER TABLE `folder`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `moref_uniq` (`moref`),
  ADD KEY `name_idx` (`name`),
  ADD KEY `moref_idx` (`moref`),
  ADD KEY `enabled_idx` (`enabled`);

--
-- Indexes for table `host`
--
ALTER TABLE `host`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `moref_uniq` (`moref`),
  ADD KEY `parent_idx` (`parent`);

--
-- Indexes for table `virtualmachine`
--
ALTER TABLE `virtualmachine`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `moref_uniq` (`moref`),
  ADD KEY `parent_idx` (`parent`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `cluster`
--
ALTER TABLE `cluster`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `datacenter`
--
ALTER TABLE `datacenter`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `folder`
--
ALTER TABLE `folder`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;
--
-- AUTO_INCREMENT for table `host`
--
ALTER TABLE `host`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `virtualmachine`
--
ALTER TABLE `virtualmachine`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;
--
-- Constraints for dumped tables
--

--
-- Constraints for table `cluster`
--
ALTER TABLE `cluster`
  ADD CONSTRAINT `parent_fk` FOREIGN KEY (`parent`) REFERENCES `folder` (`id`);

--
-- Constraints for table `datacenter`
--
ALTER TABLE `datacenter`
  ADD CONSTRAINT `datacenter_datastore_fk` FOREIGN KEY (`datastore_folder`) REFERENCES `folder` (`id`),
  ADD CONSTRAINT `datacenter_host_fk` FOREIGN KEY (`host_folder`) REFERENCES `folder` (`id`),
  ADD CONSTRAINT `datacenter_network_fk` FOREIGN KEY (`network_folder`) REFERENCES `folder` (`id`),
  ADD CONSTRAINT `datacenter_vm_fk` FOREIGN KEY (`vm_folder`) REFERENCES `folder` (`id`);

--
-- Constraints for table `host`
--
ALTER TABLE `host`
  ADD CONSTRAINT `host_parent_fk` FOREIGN KEY (`parent`) REFERENCES `folder` (`id`);

--
-- Constraints for table `virtualmachine`
--
ALTER TABLE `virtualmachine`
  ADD CONSTRAINT `virtualmachine_parent_fk` FOREIGN KEY (`parent`) REFERENCES `folder` (`id`);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
