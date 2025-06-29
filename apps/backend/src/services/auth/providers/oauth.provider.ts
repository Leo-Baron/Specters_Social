import { ProvidersInterface } from '@gitroom/backend/services/auth/providers.interface';

export class OauthProvider implements ProvidersInterface {
  private readonly authUrl: string;
  private readonly baseUrl: string;
  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly frontendUrl: string;
  private readonly tokenUrl: string;
  private readonly userInfoUrl: string;

  constructor() {
    const {
      SPECTERS_OAUTH_AUTH_URL,
      SPECTERS_OAUTH_CLIENT_ID,
      SPECTERS_OAUTH_CLIENT_SECRET,
      SPECTERS_OAUTH_TOKEN_URL,
      SPECTERS_OAUTH_URL,
      SPECTERS_OAUTH_USERINFO_URL,
      FRONTEND_URL,
    } = process.env;

    if (!SPECTERS_OAUTH_USERINFO_URL)
      throw new Error(
        'SPECTERS_OAUTH_USERINFO_URL environment variable is not set'
      );
    if (!SPECTERS_OAUTH_URL)
      throw new Error('SPECTERS_OAUTH_URL environment variable is not set');
    if (!SPECTERS_OAUTH_TOKEN_URL)
      throw new Error('SPECTERS_OAUTH_TOKEN_URL environment variable is not set');
    if (!SPECTERS_OAUTH_CLIENT_ID)
      throw new Error('SPECTERS_OAUTH_CLIENT_ID environment variable is not set');
    if (!SPECTERS_OAUTH_CLIENT_SECRET)
      throw new Error(
        'SPECTERS_OAUTH_CLIENT_SECRET environment variable is not set'
      );
    if (!SPECTERS_OAUTH_AUTH_URL)
      throw new Error('SPECTERS_OAUTH_AUTH_URL environment variable is not set');
    if (!FRONTEND_URL)
      throw new Error('FRONTEND_URL environment variable is not set');

    this.authUrl = SPECTERS_OAUTH_AUTH_URL;
    this.baseUrl = SPECTERS_OAUTH_URL;
    this.clientId = SPECTERS_OAUTH_CLIENT_ID;
    this.clientSecret = SPECTERS_OAUTH_CLIENT_SECRET;
    this.frontendUrl = FRONTEND_URL;
    this.tokenUrl = SPECTERS_OAUTH_TOKEN_URL;
    this.userInfoUrl = SPECTERS_OAUTH_USERINFO_URL;
  }

  generateLink(): string {
    const params = new URLSearchParams({
      client_id: this.clientId,
      scope: 'openid profile email',
      response_type: 'code',
      redirect_uri: `${this.frontendUrl}/settings`,
    });

    return `${this.authUrl}/?${params.toString()}`;
  }

  async getToken(code: string): Promise<string> {
    const response = await fetch(`${this.tokenUrl}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: this.clientId,
        client_secret: this.clientSecret,
        code,
        redirect_uri: `${this.frontendUrl}/settings`,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Token request failed: ${error}`);
    }

    const { access_token } = await response.json();
    return access_token;
  }

  async getUser(access_token: string): Promise<{ email: string; id: string }> {
    const response = await fetch(`${this.userInfoUrl}`, {
      headers: {
        Authorization: `Bearer ${access_token}`,
        Accept: 'application/json',
      },
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`User info request failed: ${error}`);
    }

    const { email, sub: id } = await response.json();
    return { email, id };
  }
}
