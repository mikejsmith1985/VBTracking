// The build this page is running.
//
// It exists so "it is still broken" and "you are running last week's copy" can be told
// apart in one glance, by whoever is holding the phone. Bump it with the service worker
// cache, which is the thing that actually decides what a device is running -- a test
// asserts the two agree, because a badge that can drift lies exactly when it is trusted.
export const APP_VERSION = 'v17'
