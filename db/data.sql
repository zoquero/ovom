--
-- Adding root because it doesn't appear as a folder in Folder views
--
INSERT INTO `folder` (`id`, `name`, `mo_ref`, `parent`) VALUES (0, 'Datacenters',  'group-d1', 0);
UPDATE `folder` set `id` = 0 where `mo_ref` = 'group-d1';
INSERT INTO `entity_types`(`id`, `type_name`) VALUES (0, 'Folder');
INSERT INTO `entity_types`(`id`, `type_name`) VALUES (1, 'Datacenter');
INSERT INTO `entity_types`(`id`, `type_name`) VALUES (2, 'ClusterComputeResource');
INSERT INTO `entity_types`(`id`, `type_name`) VALUES (3, 'HostSystem');
INSERT INTO `entity_types`(`id`, `type_name`) VALUES (4, 'VirtualMachine');
