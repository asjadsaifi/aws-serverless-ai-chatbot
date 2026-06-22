import React from 'react';
import './Message.css';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

interface MessageProps {
  message: ChatMessage;
}

/**
 * Single chat message bubble.
 * User messages appear on the right (blue).
 * AI messages appear on the left (dark).
 */
function Message({ message }: MessageProps) {
  const isUser = message.role === 'user';
  const time = new Date(message.timestamp).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <div className={`message ${isUser ? 'message-user' : 'message-ai'}`}>
      <div className="message-avatar">
        {isUser ? '👤' : '🤖'}
      </div>
      <div className="message-body">
        <div className="message-bubble">
          {/* Preserve newlines in AI responses */}
          {message.content.split('\n').map((line, i) => (
            <React.Fragment key={i}>
              {line}
              {i < message.content.split('\n').length - 1 && <br />}
            </React.Fragment>
          ))}
        </div>
        <span className="message-time">{time}</span>
      </div>
    </div>
  );
}

export default Message;
