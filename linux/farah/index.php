<?php
use Slothsoft\Farah\FarahUrl\FarahUrlStreamIdentifier;
use Slothsoft\Farah\Http\MessageFactory;
use Slothsoft\Farah\Kernel;
use Slothsoft\Farah\RequestStrategy\LookupAssetStrategy;
use Slothsoft\Farah\RequestStrategy\LookupPageStrategy;
use Slothsoft\Farah\ResponseStrategy\SendHeaderAndBodyStrategy;

require_once '/var/www/vendor/autoload.php';

$request = MessageFactory::createServerRequest($_SERVER, $_REQUEST, $_FILES);
if (preg_match('~^/[^/]+@[^/]+~', $request->getUri()->getPath())) {
    $requestStrategy = new LookupAssetStrategy();
} else {
    $pageType = getenv('FARAH_PAGE_TYPE');
    $defaultStream = $pageType
        ? FarahUrlStreamIdentifier::createFromString($pageType)
        : null;
    $requestStrategy = new LookupPageStrategy(null, $defaultStream);
}
$responseStrategy = new SendHeaderAndBodyStrategy();

$kernel = Kernel::getInstance();
$kernel->handle($requestStrategy, $responseStrategy, $request);
