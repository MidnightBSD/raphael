pipeline {
  agent any
  stages {
    stage('build') {
      steps {
          cmakeBuild(
            installation: 'InSearchPath'
          )
      }
    }
  }
}
