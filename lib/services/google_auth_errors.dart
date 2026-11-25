String googleAuthErrorMessage(String code) => switch (code) {
  'popup-closed-by-user' || 'cancelled-popup-request' =>
    'Entrada cancelada. Você pode tentar novamente ou entrar com sua senha.',
  'popup-blocked' =>
    'Permita pop-ups para este site e tente entrar com Google novamente.',
  'operation-not-allowed' =>
    'O login Google ainda precisa ser habilitado no Firebase.',
  'unauthorized-domain' =>
    'Este endereço do site ainda não foi autorizado no Firebase.',
  'account-exists-with-different-credential' =>
    'Este e-mail já possui outro método de entrada. Use o método original, como e-mail e senha.',
  'network-request-failed' => 'Confira sua conexão e tente novamente.',
  'user-disabled' => 'Esta conta foi desativada. Contate a equipe do projeto.',
  'too-many-requests' =>
    'Muitas tentativas. Aguarde um pouco e tente novamente.',
  _ => 'Não foi possível entrar com Google. Tente novamente.',
};
