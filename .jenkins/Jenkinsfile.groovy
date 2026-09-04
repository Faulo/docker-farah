def assertValue(actual, expected, description) {
    if (actual != expected) {
        error "${description}: expected '${expected}', got '${actual}'"
    }
}

def candidateImage() {
    return "$DOCKER_NAMESPACE/$DOCKER_IMAGE:$DOCKER_TAG"
}

def curlCommand(containerId, arguments) {
    return "docker exec ${containerId} curl ${arguments}"
}

def responseStatus(containerId, path, retry = false) {
    def nullDevice = isUnix() ? '/dev/null' : 'NUL'
    def writeOut = isUnix() ? "'%{http_code}'" : '"%{http_code}"'
    def retryArguments = retry ? '--retry 30 --retry-connrefused --retry-delay 1 ' : ''
    def errorArguments = retry ? '' : '--show-error '
    def arguments = "--silent ${errorArguments}${retryArguments}--output ${nullDevice} --write-out ${writeOut} http://localhost${path}"
    return execStdout(curlCommand(containerId, arguments))
}

def responseBody(containerId, path) {
    return execStdout(curlCommand(containerId, "--fail --silent --show-error http://localhost${path}"))
}

def responseContentType(containerId, path) {
    def nullDevice = isUnix() ? '/dev/null' : 'NUL'
    def writeOut = isUnix() ? "'%{content_type}'" : '"%{content_type}"'
    def arguments = "--fail --silent --show-error --output ${nullDevice} --write-out ${writeOut} http://localhost${path}"
    return execStdout(curlCommand(containerId, arguments))
}

def testImage(pageType, expectedContentType) {
    def containerId = execStdout("docker run --detach --env FARAH_PAGE_TYPE=${pageType} ${candidateImage()}")
    try {
        try {
            responseStatus(containerId, '/', true)
        } catch (Exception exception) {
            exec("docker logs ${containerId}")
            error "${candidateImage()} did not start serving HTTP"
        }

        def phpInfoPath = '/slothsoft@farah/phpinfo'
        assertValue(responseStatus(containerId, phpInfoPath), '200', "HTTP status for ${phpInfoPath}")
        assertValue(responseContentType(containerId, phpInfoPath), expectedContentType, "Content-Type for ${phpInfoPath} with FARAH_PAGE_TYPE=${pageType}")

        def phpInfo = responseBody(containerId, phpInfoPath)
        if (!phpInfo.contains('<title>PHP') || !phpInfo.contains('phpinfo()')) {
            error "${phpInfoPath} did not return HTML phpinfo output"
        }

        assertValue(responseStatus(containerId, '/'), '501', 'HTTP status for /')
        assertValue(responseStatus(containerId, '/AboutMe/'), '410', 'HTTP status for /AboutMe/')
    } finally {
        exec("docker rm --force --volumes ${containerId}")
    }
}

properties([
    parameters([
        choice(
            name: 'DOCKER_NAMESPACE',
            choices: ['faulo', 'tmp'],
            description: 'Docker image namespace to test'
        )
    ]),
    disableConcurrentBuilds(),
    disableResume()
])

def hosts = ['Dende', 'Garl']
def dockerNamespace = params.DOCKER_NAMESPACE ?: 'faulo'
def dockerTag = dockerNamespace == 'tmp' ? 'latest' : '8.5'

stage('Integration Tests') {
    for (def host in hosts) {
        stage("Host: ${host}") {
            node(host) {
                deleteDir()
                checkout scm

                catchError(
                    message: "Integration test failed on ${host}",
                    stageResult: 'FAILURE',
                    buildResult: 'FAILURE',
                    catchInterruptions: false
                ) {
                    withEnv([
                        "DOCKER_NAMESPACE=${dockerNamespace}",
                        "DOCKER_TAG=${dockerTag}"
                    ]) {
                        withEnvFile {
                            echo "Testing ${candidateImage()} on ${host}"
                            testImage('xml', 'application/xhtml+xml')
                            testImage('html', 'text/html')
                        }
                    }
                }
            }
        }
    }
}
