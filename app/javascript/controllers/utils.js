import { UAParser } from "ua-parser-js"

const POLL_INTERVAL = 1000

const poll = ({ fn, validate, interval, maxAttempts }) => {
  let attempts = 0

  const executePoll = async (resolve, reject) => {
    const result = await fn()
    attempts++

    if (!interval) {
      interval = POLL_INTERVAL
    }

    if (validate && validate(result)) {
      return resolve(result)
    } else if (maxAttempts && attempts === maxAttempts) {
      return reject(new Error("Exceeded max attempts"))
    } else {
      setTimeout(executePoll, interval, resolve, reject)
    }
  }

  return new Promise(executePoll)
}

const uaParser = new UAParser()

// Detect iOS/iPad OS
const isiOS = () => {
  let device = uaParser.getDevice()
  let isiPhoneOriPod = device && (device.model === "iPhone" || device.model === "iPod")

  // Legacy iPad || iPad iOS 13 above || iPad M1
  let isiPad = device && (device.model === "iPad" ||
    (navigator.userAgent.includes("Mac") && "ontouchend" in document) ||
    (navigator.userAgent.includes("Mac Intel") && navigator.maxTouchPoints > 1))

  return isiPhoneOriPod || isiPad
}

// Detect NonApple OS (Windows/Linux/Android etc)
const isNonAppleOS = () => {
  let os = uaParser.getOS()
  return !(os.name === "Mac OS" || os.name === "iOS")
}

export { poll, uaParser, isiOS, isNonAppleOS }