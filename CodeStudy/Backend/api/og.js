import { ImageResponse } from '@vercel/og';

export const config = {
  runtime: 'edge',
};

export default async function handler(req) {
  const url = new URL(req.url, 'http://localhost');
  const concept = url.searchParams.get('concept') || '';
  const streak = parseInt(url.searchParams.get('streak') || '0', 10);
  const mastered = url.searchParams.get('mastered') === 'true';

  const headline = mastered
    ? `\uD83C\uDF93 ${concept} 마스터!`
    : `\uD83D\uDD25 ${streak}일 연속 학습 중`;

  return new ImageResponse(
    {
      type: 'div',
      props: {
        style: {
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#1E3A5F',
          padding: '60px',
        },
        children: [
          {
            type: 'div',
            props: {
              style: {
                fontSize: '64px',
                fontWeight: 'bold',
                color: '#FFFFFF',
                textAlign: 'center',
                marginBottom: '24px',
              },
              children: headline,
            },
          },
          {
            type: 'div',
            props: {
              style: {
                fontSize: '32px',
                color: '#FF6B35',
                fontWeight: '600',
              },
              children: 'CodeStudy',
            },
          },
        ],
      },
    },
    {
      width: 1200,
      height: 630,
    },
  );
}
