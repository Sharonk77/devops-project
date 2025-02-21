"use client"

import { useState, useEffect } from "react"
import { motion } from "framer-motion"

function Bubble({ x, y, size, color }: { x: number; y: number; size: number; color: string }) {
    return (
        <motion.circle
            cx={x}
            cy={y}
            r={size}
            fill={color}
            initial={{ opacity: 0, scale: 0 }}
            animate={{
                opacity: [0.7, 0.3, 0.7],
                scale: [1, 1.2, 1],
                x: x + Math.random() * 100 - 50,
                y: y + Math.random() * 100 - 50,
            }}
            transition={{
                duration: 5 + Math.random() * 10,
                repeat: Number.POSITIVE_INFINITY,
                repeatType: "reverse",
            }}
        />
    )
}

function FloatingBubbles() {
    const [bubbles, setBubbles] = useState<Array<{ id: number; x: number; y: number; size: number; color: string }>>([])

    useEffect(() => {
        const newBubbles = Array.from({ length: 50 }, (_, i) => ({
            id: i,
            x: Math.random() * window.innerWidth,
            y: Math.random() * window.innerHeight,
            size: Math.random() * 20 + 5,
            color: `rgba(${Math.random() * 255},${Math.random() * 255},${Math.random() * 255},0.3)`,
        }))
        setBubbles(newBubbles)
    }, [])

    return (
        <div className="absolute inset-0 pointer-events-none">
            <svg className="w-full h-full">
                <title>Sharon's Health-Check</title>
                {bubbles.map((bubble) => (
                    <Bubble key={bubble.id} {...bubble} />
                ))}
            </svg>
        </div>
    )
}

export default function FloatingBubblesBackground({
                                                      title = "Sharon&apos;s Web Health-Check",
                                                  }: {
    title?: string
}) {
    const words = title.split(" ")
    const [serverStatus, setServerStatus] = useState<"loading" | "up" | "down">("loading")

    useEffect(() => {
        const checkServerStatus = async () => {
            try {
                const response = await fetch(process.env.NEXT_PUBLIC_API_URL as string)
                if (response.ok) {
                    setServerStatus("up")
                } else {
                    setServerStatus("down")
                }
            } catch (error) {
                console.error("Error checking server status:", error);
                setServerStatus("down")
            }
        }

        checkServerStatus()

        // Refresh status every 10 seconds
        const interval = setInterval(checkServerStatus, 10000)
        return () => clearInterval(interval)
    }, [])

    return (
        <div className="relative min-h-screen w-full flex items-center justify-center overflow-hidden bg-gradient-to-br from-blue-100 to-purple-100 dark:from-blue-900 dark:to-purple-900">
            <FloatingBubbles />

            <div className="relative z-10 container mx-auto px-4 md:px-6 text-center">
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 2 }}
                    className="max-w-4xl mx-auto"
                >
                    <h1 className="text-5xl sm:text-7xl md:text-8xl font-bold mb-4 tracking-tighter">
                        {words.map((word, wordIndex) => (
                            <span key={wordIndex} className="inline-block mr-4 last:mr-0">
                {word.split("").map((letter, letterIndex) => (
                    <motion.span
                        key={`${wordIndex}-${letterIndex}`}
                        initial={{ y: 100, opacity: 0 }}
                        animate={{ y: 0, opacity: 1 }}
                        transition={{
                            delay: wordIndex * 0.1 + letterIndex * 0.03,
                            type: "spring",
                            stiffness: 150,
                            damping: 25,
                        }}
                        className="inline-block text-transparent bg-clip-text
                               bg-gradient-to-r from-blue-600 to-purple-600
                               dark:from-blue-300 dark:to-purple-300"
                    >
                        {letter}
                    </motion.span>
                ))}
              </span>
                        ))}
                    </h1>

                    {/* Server Status */}
                    <p className="text-xl font-semibold mt-2">
                        {serverStatus === "loading" ? "Checking server status... ⏳" :
                            serverStatus === "up" ? "Server is running ✅" :
                                "Server is Down ❌"}
                    </p>

                </motion.div>
            </div>
        </div>
    )
}
