module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['@testing-library/jest-dom'],
  moduleNameMapper: {
    '\\.(css|less|scss|sass)$': 'identity-obj-proxy',
  },
    moduleNameMapper: {
      '\\.(css|less|scss|sass)$': 'identity-obj-proxy',
    },
    setupFilesAfterEnv: ['@testing-library/jest-dom'],
    collectCoverageFrom: [
      'src/**/*.{js,jsx}',
      '!src/**/*.stories.{js,jsx}',
      '!src/**/index.{js,jsx}',
      '!src/serviceWorker.js',
      '!src/setupTests.js',
    ],
}
