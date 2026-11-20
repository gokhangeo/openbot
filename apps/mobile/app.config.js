const { existsSync } = require("node:fs");
const { join } = require("node:path");

// Android notifications come through Firebase Cloud Messaging, which needs the Firebase file of the
// app. The file is optional, so the app builds before the Firebase project exists, and such a build
// gets no notifications on Android. The file has public identifiers only; the account service has the
// key that sends.
const GOOGLE_SERVICES_FILE = "./google-services.json";

/** @param {{ config: import('expo/config').ExpoConfig }} context */
const upstreamConfig = ({ config }) =>
  existsSync(join(__dirname, GOOGLE_SERVICES_FILE))
    ? { ...config, android: { ...config.android, googleServicesFile: GOOGLE_SERVICES_FILE } }
    : config;

// Reis eklentisi (gokhangeo/openbot fork'u): ad, paket kimlikleri ve telefon izinleri reis/reis.config.js'de.
// REIS=0 ile OpenBot'un kendi ayarlarıyla derlenir.
module.exports = (context) =>
  process.env.REIS === "0" ? upstreamConfig(context) : require("./reis/reis.config.js")(upstreamConfig(context));
