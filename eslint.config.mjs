const sharedRules = {
  eqeqeq: "error",
  "no-undef": "error",
  "no-unused-vars": ["error", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" }],
  "no-var": "error",
  "object-shorthand": "error",
  "prefer-arrow-callback": "error",
  "prefer-const": "error"
}

export default [
  {
    ignores: [".idea/**"]
  },
  {
    files: ["*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "script",
      globals: {
        module: "readonly"
      }
    },
    rules: sharedRules
  },
  {
    files: ["tests/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "commonjs"
    },
    rules: sharedRules
  }
]
