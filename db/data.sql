--
-- Adding root because it doesn't appear as a folder in Folder views
--
INSERT INTO `folder` (`id`, `name`, `moref`, `parent`) VALUES (0, 'Datacenters',  'group-d1', 0);
UPDATE `folder` set `id` = 0 where `moref` = 'group-d1';
