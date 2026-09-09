<?php
declare(strict_types = 1);

use Slothsoft\Farah\Kernel;
use Slothsoft\Farah\Module\Module;

Module::registerWithXmlManifestAndDefaultAssets('slothsoft@docker-farah-integration-test', __DIR__ . DIRECTORY_SEPARATOR . 'assets');
Kernel::setCurrentSitemap('farah://slothsoft@docker-farah-integration-test/sitemap');
