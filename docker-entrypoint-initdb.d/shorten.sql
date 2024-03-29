CREATE TABLE `t_url` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `url` VARCHAR(256) NOT NULL COMMENT '短链对应的原始链接',
    `ctime` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `mtime` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE INDEX `ux__url` (`url`)
) AUTO_INCREMENT=1000001;
