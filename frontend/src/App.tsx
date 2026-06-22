import React from 'react';
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import ChatWindow from './components/ChatWindow';
import Header from './components/Header';
import './App.css';

/**
 * Root component.
 * Amplify Authenticator wraps the whole app — unauthenticated
 * users see the sign-in/sign-up form, authenticated users see the chat.
 */
function App() {
  return (
    <Authenticator
      loginMechanisms={['email']}
      signUpAttributes={['email']}
    >
      {({ signOut, user }) => (
        <div className="app">
          <Header
            userEmail={user?.signInDetails?.loginId ?? ''}
            onSignOut={signOut!}
          />
          <ChatWindow />
        </div>
      )}
    </Authenticator>
  );
}

export default App;
