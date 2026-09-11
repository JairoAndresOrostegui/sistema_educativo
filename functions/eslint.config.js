const js = require("@eslint/js");
const google = require("eslint-config-google");
const globals = require("globals");

const googleRules = {...google.rules};
delete googleRules["valid-jsdoc"];
delete googleRules["require-jsdoc"];

module.exports = [
  {
    ignores: ["node_modules/**", "coverage/**"],
  },
  js.configs.recommended,
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: globals.node,
    },
    rules: {
      ...googleRules,
      "no-restricted-globals": ["error", "name", "length"],
      "prefer-arrow-callback": "error",
      "quotes": ["error", "double", {allowTemplateLiterals: true}],
    },
  },
  {
    files: ["test/**/*.js"],
    languageOptions: {
      globals: globals.mocha,
    },
  },
];
