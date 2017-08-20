INSERT INTO `folder` (`name`, `moref`, `parent`) VALUES ('vdc01', 'datacenter-2', '0');
UPDATE `folder` set `id` = 2 where `moref` = 'datacenter-2';
INSERT INTO `folder` (`name`, `moref`, `parent`) VALUES ('host', 'group-h4', '2');
UPDATE `folder` set `id` = 3 where `moref` = 'group-h4';
INSERT INTO `folder` (`name`, `moref`, `parent`) VALUES ('vmZZ', 'group-v3', '2');
UPDATE `folder` set `id` = 4 where `moref` = 'group-v3';
