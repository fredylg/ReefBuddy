/** Vite raw imports used by tests (e.g. JWS fixtures). Script file on purpose: wildcard module declarations must be global. */
declare module '*?raw' {
  const content: string;
  export default content;
}
