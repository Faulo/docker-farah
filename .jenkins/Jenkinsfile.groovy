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

def capture(command) {
    if (isUnix()) {
        return sh(script: command, returnStdout: true).trim()
    }
    return bat(script: "@${command}", returnStdout: true).trim()
}

def execute(command) {
    if (isUnix()) {
        sh command
    } else {
        bat "@${command}"
    }
}

def responseStatus(containerId, path, retry = false) {
    def nullDevice = isUnix() ? '/dev/null' : 'NUL'
    def writeOut = isUnix() ? "'%{http_code}'" : '"%%{http_code}"'
    def retryArguments = retry ? '--retry 120 --retry-connrefused --retry-delay 1 ' : ''
    def arguments = "--silent --show-error ${retryArguments}--output ${nullDevice} --write-out ${writeOut} http://localhost${path}"
    return capture(curlCommand(containerId, arguments))
}

def responseBody(containerId, path) {
    return capture(curlCommand(containerId, "--fail --silent --show-error http://localhost${path}"))
}

def testImage() {
    def containerId = capture("docker run --detach ${candidateImage()}")
    try {
        responseStatus(containerId, '/', true)

        def phpInfoPath = '/slothsoft@farah/phpinfo'
        assertValue(responseStatus(containerId, phpInfoPath), '200', "HTTP status for ${phpInfoPath}")

        def phpInfo = responseBody(containerId, phpInfoPath)
        if (!phpInfo.contains('<title>PHP') || !phpInfo.contains('phpinfo()')) {
            error "${phpInfoPath} did not return HTML phpinfo output"
        }

        assertValue(responseStatus(containerId, '/'), '404', 'HTTP status for /')
        assertValue(responseStatus(containerId, '/AboutMe/'), '404', 'HTTP status for /AboutMe/')
    } finally {
        execute("docker rm --force --volumes ${containerId}")
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
                            testImage()
                        }
                    }
                }
            }
        }
    }
}
