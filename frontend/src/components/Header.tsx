import React from 'react';
import './Header.css';

interface HeaderProps {
  userEmail: string;
  onSignOut: () => void;
}

/**
 * Top navigation bar — shows app name, logged-in email, sign out button.
 */
function Header({ userEmail, onSignOut }: HeaderProps) {
  return (
    <header className="header">
      <div className="header-brand">
        <span className="header-logo">🤖</span>
        <span className="header-title">AI Chatbot</span>
        <span className="header-badge">Powered by Amazon Bedrock</span>
      </div>
      <div className="header-user">
        <span className="header-email">{userEmail}</span>
        <button className="header-signout" onClick={onSignOut}>
          Sign Out
        </button>
      </div>
    </header>
  );
}

export default Header;
