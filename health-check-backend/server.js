const express = require("express");
const cors = require("cors");
const app = express();
const PORT = process.env.PORT || 80;

app.use(cors()); // Enable CORS

app.get("/health", (req, res) => {
    res.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
    setTimeout(() => {
        res.status(200).send("OK");
    }, 3000)
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
