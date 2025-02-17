const express = require("express");
const cors = require("cors");
const app = express();
const PORT = process.env.PORT || 80;

app.use(cors()); // Enable CORS

app.get("/health", (req, res) => {
    res.status(200).send("OK");
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
