ALTER TABLE `perf_metric` ADD `warn_threshold` FLOAT NULL DEFAULT NULL AFTER `instance`, ADD `crit_threshold` FLOAT NULL DEFAULT NULL AFTER `warn_threshold`, ADD `last_value` FLOAT NULL DEFAULT NULL AFTER `crit_threshold`;
ALTER TABLE `perf_counter_info` ADD `warn_threshold` FLOAT NULL DEFAULT NULL AFTER `per_device_level`, ADD `crit_threshold` FLOAT NULL DEFAULT NULL AFTER `warn_threshold`;
CREATE TABLE `ovomdb`.`entity_types` ( `id` TINYINT NOT NULL , `type_name` VARCHAR(255) NOT NULL , PRIMARY KEY (`id`)) ENGINE = InnoDB;
CREATE TABLE `ovomdb`.`alerts` ( `id` INT(10) NOT NULL , `entity_type` TINYINT NOT NULL , `entity_moref` VARCHAR(255) NOT NULL , `is_critical` BOOLEAN NULL DEFAULT NULL , `perf_metric_id` INT(10) UNSIGNED NOT NULL , PRIMARY KEY (`id`)) ENGINE = InnoDB;
ALTER TABLE `alerts` ADD INDEX ( `entity_type`); 
ALTER TABLE `alerts` ADD CONSTRAINT `entity_type_fk` FOREIGN KEY (`entity_type`) REFERENCES `entity_types`(`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
