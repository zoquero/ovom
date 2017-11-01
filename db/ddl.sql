-- phpMyAdmin SQL Dump
-- version 4.5.4.1deb2ubuntu2
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Aug 10, 2017 at 04:34 PM
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
  `mo_ref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_spanish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `datacenter`
--

CREATE TABLE `datacenter` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `mo_ref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL,
  `datastore_folder` int(10) UNSIGNED NOT NULL,
  `vm_folder` int(10) UNSIGNED NOT NULL,
  `host_folder` int(10) UNSIGNED NOT NULL,
  `network_folder` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_spanish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `folder`
--

CREATE TABLE `folder` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `mo_ref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_spanish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `host`
--

CREATE TABLE `host` (
  `id` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `mo_ref` varchar(255) NOT NULL,
  `parent` int(11) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_spanish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `virtualmachine`
--

CREATE TABLE `virtualmachine` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `mo_ref` varchar(255) NOT NULL,
  `parent` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE utf8_spanish_ci;

--
-- Table structure for table `perf_counter_info`
--

CREATE TABLE `perf_counter_info` (
  `pci_key` int(10) UNSIGNED NOT NULL,
  `name_info_key` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `name_info_label` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `name_info_summary` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `group_info_key` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `group_info_label` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `group_info_summary` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `unit_info_key` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `unit_info_label` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `unit_info_summary` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `rollup_type` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `stats_type` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `pci_level` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `per_device_level` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `crit_threshold` float NULL DEFAULT NULL,
  `warn_threshold` float NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci COMMENT='To store PerfCounterInfo objects';

--
-- Table structure for table `perf_counter_info`
--

CREATE TABLE `perf_metric` (
  `id` int(10) UNSIGNED NOT NULL,
  `mo_ref` varchar(255) COLLATE utf8_spanish_ci NOT NULL  COMMENT 'No FK because we want to allow for hosts and VMs to be temporarily out of inventory and it would break integrity. More over, we do not designed a single base entity table to have a single index controlling the unicity of mo_ref. It does not introduce any problem.',
  `counter_id` int(10) UNSIGNED NOT NULL COMMENT 'fk perf_counter_info.pci_key',
  `instance` varchar(255) COLLATE utf8_spanish_ci NOT NULL,
  `crit_threshold` float NULL DEFAULT NULL,
  `warn_threshold` float NULL DEFAULT NULL,
  `last_value` float NULL DEFAULT NULL,
  `last_collection` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;

--
-- Table structure for table `entity_types`
--

CREATE TABLE `entity_types` (
  `id` TINYINT NOT NULL ,
  `type_name` VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;

--
-- Table structure for table `alarms`
--

CREATE TABLE `alarms` (
  `id` INT(10) NOT NULL ,
  `entity_type` TINYINT NOT NULL ,
  `entity_moref` VARCHAR(255) NOT NULL ,
  `is_critical` BOOLEAN NULL DEFAULT NULL ,
  `perf_metric_id` INT(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `cluster`
--
ALTER TABLE `cluster`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `mo_ref_uniq` (`mo_ref`),
  ADD KEY `parent_idx` (`parent`);

--
-- Indexes for table `datacenter`
--
ALTER TABLE `datacenter`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `mo_ref_uniq` (`mo_ref`),
  ADD KEY `parent_idx` (`parent`),
  ADD KEY `mo_ref_idx` (`mo_ref`),
  ADD KEY `folder_idx` (`datastore_folder`),
  ADD KEY `vm_folder_idx` (`vm_folder`),
  ADD KEY `host_folder_idx` (`host_folder`),
  ADD KEY `network_folder_idx` (`network_folder`);

--
-- Indexes for table `folder`
--
ALTER TABLE `folder`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `mo_ref_uniq` (`mo_ref`),
  ADD KEY `name_idx` (`name`),
  ADD KEY `mo_ref_idx` (`mo_ref`);

--
-- Indexes for table `host`
--
ALTER TABLE `host`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `mo_ref_uniq` (`mo_ref`),
  ADD KEY `parent_idx` (`parent`);

--
-- Indexes for table `virtualmachine`
--
ALTER TABLE `virtualmachine`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `mo_ref_uniq` (`mo_ref`),
  ADD KEY `parent_idx` (`parent`);

--
-- Indexes for table `perf_counter_info`
--
ALTER TABLE `perf_counter_info`
  ADD PRIMARY KEY (`pci_key`);

--
-- Indexes for table `perf_metric`
--
ALTER TABLE `perf_metric`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `mo_ref` (`mo_ref`,`counter_id`,`instance`),
  ADD KEY `counter_id` (`counter_id`);

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
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;
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
-- AUTO_INCREMENT for table `perf_metric`
--
ALTER TABLE `perf_metric`
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

--
-- Constraints for table `perf_metric`
--
ALTER TABLE `perf_metric`
  ADD CONSTRAINT `pmi_pci_fk` FOREIGN KEY (`counter_id`) REFERENCES `perf_counter_info` (`pci_key`);

--
-- Constraints for table `entity_types`
--
ALTER TABLE `entity_types`
  ADD PRIMARY KEY (`id`);

--
-- Constraints for table `alarms`
--
ALTER TABLE `alarms`
  ADD PRIMARY KEY (`id`),
  ADD INDEX ( `entity_type`); 

ALTER TABLE `alarms`
  ADD CONSTRAINT `entity_type_fk` FOREIGN KEY (`entity_type`) REFERENCES `entity_types`(`id`);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
