pipeline {
    agent none

    options {
        disableConcurrentBuilds()
        disableResume()
        disableRestartFromStage()
    }

    parameters {
        choice(
            name: 'DOCKER_NAMESPACE',
            choices: ['faulo', 'tmp'],
            description: 'Docker image namespace to test'
        )
    }
	
	environment {
		PESTER_MAJOR_VERSION = '6'
	}

    stages {
        stage('Integration Tests') {
            steps {
                script {
                    def properties = readTrusted('.jenkins/pesterProject.properties')
                    def pesterConfig = readProperties text: properties

					pesterProject(pesterConfig, params.DOCKER_NAMESPACE ?: 'faulo')
                }
            }
        }
    }
}

def requiredProperty(config, name) {
    def value = config[name]?.trim()
    if (!value) {
        error "Missing required property '${name}' in .jenkins/pesterProject.properties"
    }
    return value
}

def commaSeparated(value) {
    return value
        ? value.split(',').collect { it.trim() }.findAll { it }
        : []
}

def parseCredentialPairs(value, description, bindingFactory) {
    return commaSeparated(value).collect { entry ->
        def parts = entry.split('\\|', 2)
        if (parts.size() != 2 || !parts[0].trim() || !parts[1].trim()) {
            error "Invalid ${description} credential binding '${entry}'; expected variable|credential-id"
        }
        return bindingFactory(parts[0].trim(), parts[1].trim())
    }
}

def credentialBindings(config) {
    def bindings = []
    bindings.addAll(parseCredentialPairs(
        config.usernamePasswordCredentials,
        'username/password',
        { variable, id ->
            usernamePassword(
                credentialsId: id,
                usernameVariable: "${variable}_USR",
                passwordVariable: "${variable}_PSW"
            )
        }
    ))
    bindings.addAll(parseCredentialPairs(
        config.stringCredentials,
        'string',
        { variable, id -> string(credentialsId: id, variable: variable) }
    ))
    return bindings
}

def withOptionalCredentials(bindings, Closure body) {
    if (bindings) {
        withCredentials(bindings, body)
    } else {
        body()
    }
}

def pesterProject(config, dockerNamespace) {
    def targets = commaSeparated(requiredProperty(config, 'targets'))
    def variants = commaSeparated(requiredProperty(config, 'variants'))
    def variantEnvironment = config.variantEnvironment?.trim()
    def timeoutMinutes = (config.timeoutMinutes?.trim() ?: '60') as Integer
    def bindings = credentialBindings(config)

    if (timeoutMinutes <= 0) {
        error 'timeoutMinutes must be a positive integer'
    }

    for (def target in targets) {
		stage("Host: ${target}") {
			node(target) {
				def os = isWindows() ? 'windows' : 'linux'
			
				checkout scm
				dir('.reports') {
					deleteDir()
				}

				exec "pwsh -NoLogo -NoProfile -NonInteractive -File .jenkins/Install-Pester.ps1 -MajorVersion ${env.PESTER_MAJOR_VERSION}"

				for (def variant in variants) {
					def safeTarget = target.replaceAll('[^A-Za-z0-9_.-]+', '-')
					def safeVariant = variant.replaceAll('[^A-Za-z0-9_.-]+', '-')
					def resultsPath = ".reports/pester-${safeTarget}-${os}-${safeVariant}.xml"
					def capabilities = config["capabilities.${target}"]?.trim() ?: ''
					def variantEnvironmentEntry = variantEnvironment
						? ["${variantEnvironment}=${variant}"]
						: []
					def imageTagTemplate = dockerNamespace == 'tmp'
						? config.candidateImageTag?.trim()
						: config.publishedImageTag?.trim()
					def imageTag = (imageTagTemplate ?: 'latest').replace('<variant>', variant)

					withEnvFile {
						withEnv(variantEnvironmentEntry + [
							"DOCKER_NAMESPACE=${dockerNamespace}",
							"DOCKER_TAG=${imageTag}",
							"PESTER_IMAGE=${dockerNamespace}/${env.DOCKER_IMAGE}:${imageTag}",
							"PESTER_OS=${os}",
							"PESTER_VARIANT=${variant}",
							"PESTER_CAPABILITIES=${capabilities}",
							"PESTER_RESULTS_PATH=${resultsPath}"
						]) {
							withOptionalCredentials(bindings) {
								stage("${env.PESTER_IMAGE}") {
									catchError(
										message: "Pester integration tests failed for ${env.PESTER_IMAGE} on ${target}",
										stageResult: 'FAILURE',
										buildResult: 'FAILURE',
										catchInterruptions: false
									) {
										timeout(time: timeoutMinutes, unit: 'MINUTES') {
											echo "Testing ${env.PESTER_IMAGE} on ${target}"
											try {
												exec 'pwsh -NoLogo -NoProfile -NonInteractive -File .jenkins/Invoke-IntegrationTests.ps1 -Path tests'
											} finally {
												junit(
													testResults: resultsPath,
													allowEmptyResults: false
												)
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
    }
}
