pipeline {
  agent any
  stages {
    stage('build') {
      steps {
          cmakeBuild(
            installation: 'InSearchPath',
            buildDir: '_build',
            sourceDir: '.',
            steps: [[args: 'all']]
          )
      }
    }
  }
}
