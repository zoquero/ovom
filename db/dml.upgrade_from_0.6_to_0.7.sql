ALTER TABLE `perf_metric` ADD `crit_threshold` FLOAT NULL DEFAULT NULL AFTER `warn_threshold`, ADD `warn_threshold` FLOAT NULL DEFAULT NULL AFTER `instance`, ADD `last_value` FLOAT NULL DEFAULT NULL AFTER `crit_threshold`;
ALTER TABLE `perf_counter_info` ADD `crit_threshold` FLOAT NULL DEFAULT NULL AFTER `warn_threshold`, ADD `warn_threshold` FLOAT NULL DEFAULT NULL AFTER `per_device_level`;
CREATE TABLE `ovomdb`.`entity_type` ( `id` TINYINT NOT NULL , `type_name` VARCHAR(255) NOT NULL , PRIMARY KEY (`id`)) ENGINE = InnoDB;
CREATE TABLE `ovomdb`.`alarm` ( `id` INT(10) NOT NULL , `entity_type` TINYINT NOT NULL , `mo_ref` VARCHAR(255) NOT NULL , `is_critical` BOOLEAN NULL DEFAULT NULL , `perf_metric_id` INT(10) UNSIGNED NOT NULL , `is_acknowledged` BOOLEAN NULL DEFAULT NULL , `is_active` BOOLEAN NULL DEFAULT NULL , `alarm_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP , `last_change` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP , PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;
ALTER TABLE `alarm` MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;
ALTER TABLE `alarm` ADD INDEX ( `entity_type`); 
ALTER TABLE `alarm` ADD CONSTRAINT `entity_type_fk` FOREIGN KEY (`entity_type`) REFERENCES `entity_type`(`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
