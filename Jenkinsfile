pipeline {
  agent any
  stages {
    stage('build') {
      steps {
          sh 'cmake -S . -B _build'
          sh 'cmake --build _build'
      }
    }
  }
}
