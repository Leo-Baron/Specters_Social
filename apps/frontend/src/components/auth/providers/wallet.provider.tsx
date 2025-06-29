'use client';

import React, { FC, useCallback } from 'react';
import { WalletUiProvider } from '@gitroom/frontend/components/auth/providers/placeholder/wallet.ui.provider';

// Simplified wallet provider for development - wallet functionality temporarily disabled
const WalletProvider = () => {
  const gotoLogin = useCallback(async (code: string) => {
    window.location.href = `/auth?provider=FARCASTER&code=${code}`;
  }, []);
  return <ButtonCaster login={gotoLogin} />;
};

export const ButtonCaster: FC<{
  login: (code: string) => void;
}> = (props) => {
  return <WalletUiProvider />;
};

export default WalletProvider;
