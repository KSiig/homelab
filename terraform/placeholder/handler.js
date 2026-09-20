// Placeholder Cloud Functions handler for Priskurven.
// Exists so google_cloudfunctions2_function.storage_source has a valid
// GCS object at apply time. SII-101 (CI: deploy via WIF on main) overwrites
// gs://lateral-booking-506410-k4-priskurven/function.zip with a real
// build of KSiig/priskurven. This stub must never be the deployed handler.
exports.handler = (req, res) => {
  res.status(200).send('placeholder');
};
