importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAArKApWyxmDFBChA68MbY1ZYH5vX2VUnY',
  authDomain: 'sistema-educativo-rl.firebaseapp.com',
  projectId: 'sistema-educativo-rl',
  storageBucket: 'sistema-educativo-rl.appspot.com',
  messagingSenderId: '732639994966',
  appId: '1:732639994966:web:f71afd170b50235fe847f7',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Nueva notificacion';
  const options = {
    body:
      payload.notification?.body ||
      'Tienes una novedad en el sistema educativo.',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});
