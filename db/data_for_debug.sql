INSERT INTO `folder` (`name`, `mo_ref`, `parent`) VALUES ('vdc01', 'datacenter-2', '0');
UPDATE `folder` set `id` = 2 where `mo_ref` = 'datacenter-2';
INSERT INTO `folder` (`name`, `mo_ref`, `parent`) VALUES ('host', 'group-h4', '2');
UPDATE `folder` set `id` = 3 where `mo_ref` = 'group-h4';
INSERT INTO `folder` (`name`, `mo_ref`, `parent`) VALUES ('vmZZ', 'group-v3', '2');
UPDATE `folder` set `id` = 4 where `mo_ref` = 'group-v3';
