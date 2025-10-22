import { Modal } from "antd"
import Link from "next/link"
import { MdClose } from "react-icons/md"
import { FcGoogle } from "react-icons/fc";
import { useEffect, useState } from "react";
import { FaRegEye, FaRegEyeSlash } from "react-icons/fa6";
import { GoogleAuthProvider, RecaptchaVerifier, createUserWithEmailAndPassword, getAuth, sendEmailVerification, sendPasswordResetEmail, signInWithCredential, signInWithEmailAndPassword, signInWithPhoneNumber, signInWithPopup } from "firebase/auth";
import toast from "react-hot-toast";
import { handleFirebaseAuthError, t } from "@/utils";
import { userSignUpApi } from "@/utils/api";
import { useSelector } from "react-redux";
import { Fcmtoken, settingsData } from "@/redux/reuducer/settingSlice";
import { loadUpdateData } from "../../redux/reuducer/authSlice";
import PhoneInput from 'react-phone-input-2';
import 'react-phone-input-2/lib/style.css';
import { isValidPhoneNumber } from 'libphonenumber-js';
import { usePathname, useRouter } from "next/navigation";
import MailSentSucessfully from "./MailSentSucessfully";


const LoginModal = ({ IsLoginModalOpen, setIsRegisterModalOpen, setIsLoginModalOpen, IsMailSentOpen, setIsMailSentOpen, IsRegisterModalOpen, openSentMailModal }) => {


    const router = useRouter()
    const pathname = usePathname()
    const auth = getAuth();
    const fetchFCM = useSelector(Fcmtoken);
    const systemSettingsData = useSelector(settingsData)
    const settings = systemSettingsData?.data
    const mobile_authentication = Number(settings?.mobile_authentication)
    const google_authentication = Number(settings?.google_authentication)
    const email_authentication = Number(settings?.email_authentication)
    const isDemoMode = settings?.demo_mode
    const [IsLoginScreen, setIsLoginScreen] = useState(true);
    const [IsPasswordScreen, setIsPasswordScreen] = useState(false);
    const [IsOTPScreen, setIsOTPScreen] = useState(false);
    const [inputValue, setInputValue] = useState("");
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [number, setNumber] = useState("");
    const [inputType, setInputType] = useState("");
    const [countryCode, setCountryCode] = useState("");
    const [otp, setOtp] = useState("");
    const [confirmationResult, setConfirmationResult] = useState(null);
    const [showLoader, setShowLoader] = useState(false);
    const [resendOtpLoader, setResendOtpLoader] = useState(false)
    const [IsPasswordVisible, setIsPasswordVisible] = useState(false)
    const [username, setUsername] = useState('')

    const OnHide = async () => {
        setIsLoginModalOpen(false);
        setIsLoginScreen(true);
        setIsPasswordScreen(false);
        setIsOTPScreen(false);
        setEmail("");
        setPassword("");
        setInputValue("");
        setUsername('')
        setInputType("");
        setNumber("");
        setOtp("");
        await recaptchaClear()
    };

    // Remove any non-digit characters from the country code
    const countryCodeDigitsOnly = countryCode.replace(/\D/g, '');

    // Check if the entered number starts with the selected country code
    const startsWithCountryCode = number.startsWith(countryCodeDigitsOnly);

    // If the number starts with the country code, remove it
    const formattedNumber = startsWithCountryCode ? number.substring(countryCodeDigitsOnly.length) : number;


    useEffect(() => {
        if (isDemoMode) {
            setInputType("number");
            setInputValue("919876598765");
            setNumber("919876598765");
            setCountryCode("+91");
        }
    }, [isDemoMode, IsLoginModalOpen]);


    const signin = async (email, password) => {
        try {
            const userCredential = await signInWithEmailAndPassword(auth, email, password);
            if (userCredential.length === 0) {
                toast.error(t("userNotFound"))
            } else {
                return userCredential;
            }
        } catch (error) {
            console.error("Error signing in:", error);
            throw error;
        }
    };

    const handleInputChange = (value, data) => {
        const emailRegexPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        const containsOnlyDigits = /^\d+$/.test(value);

        setInputValue(value);

        if (emailRegexPattern.test(value)) {
            setInputType("email");
            setEmail(value);
            setNumber("");
            setCountryCode("");
        } else if (containsOnlyDigits) {
            setInputType("number");
            setNumber(value);
            setCountryCode("+" + (data?.dialCode || ""));
        } else {
            setInputType("");
        }
    };
    const Signin = async (e) => {
        e.preventDefault();

        if (IsRegisterModalOpen) {

            if (!email) {
                toast.error(t("emailRequired"))
                return
            } else if (!/\S+@\S+\.\S+/.test(email)) {
                toast.error(t("emailInvalid"))
                return
            }
            if (username?.trim() === '') {
                toast.error(t("usernameRequired"))
                return
            }
            if (!password) {
                errors.password = t("passwordRequired");
                toast.error(t("passwordRequired"))
                return
            } else if (password.length < 6) {
                toast.error(t("passwordTooShort"))
                return
            }

            try {
                setShowLoader(true)
                const userCredential = await createUserWithEmailAndPassword(auth, email, password);
                const user = userCredential.user;
                await sendEmailVerification(user);
                openSentMailModal();
                try {
                    const response = await userSignUpApi.userSignup({
                        name: username ? username : "",
                        email: email ? email : "",
                        firebase_id: user?.uid,
                        type: "email",
                        registration: true
                    });
                    OnHide()
                } catch (error) {
                    console.log("error", error);
                }
            } catch (error) {
                const errorCode = error.code;
                handleFirebaseAuthError(errorCode);
            } finally {
                setShowLoader(false)
            }
        } else {
            try {
                setShowLoader(true)
                const userCredential = await signin(email, password);
                const user = userCredential.user;
                if (user.emailVerified) {
                    try {
                        const response = await userSignUpApi.userSignup({
                            name: user?.displayName ? user?.displayName : "",
                            email: user?.email,
                            firebase_id: user?.uid,
                            fcm_id: fetchFCM ? fetchFCM : "",
                            type: "email"
                        });

                        const data = response.data;
                        loadUpdateData(data)
                        if (data.error === true) {
                            toast.error(data.message);
                        }
                        else {
                            toast.success(data.message);
                        }
                        OnHide()
                        if (pathname !== '/home') {
                            if (data?.data?.mobile === "" || data?.data?.mobile === null) {
                                router.push('/profile/edit-profile')
                            }
                        }
                    } catch (error) {
                        console.error("Error:", error);
                    }
                    // Add your logic here for verified users
                } else {
                    toast.error(t('verifyEmailFirst'));
                    await sendEmailVerification(auth.currentUser);
                }
            } catch (error) {
                const errorCode = error.code;
                console.log('Error code:', errorCode);
                handleFirebaseAuthError(errorCode);
            } finally {
                setShowLoader(false)
            }
        }
    };

    const generateRecaptcha = () => {
        // Ensure auth object is properly initialized
        const auth = getAuth();

        if (!window.recaptchaVerifier) {
            // Check if container element exists
            const recaptchaContainer = document.getElementById("recaptcha-container");
            if (!recaptchaContainer) {
                console.error("Container element 'recaptcha-container' not found.");
                return null; // Return null if container element not found
            }

            try {
                // Clear any existing reCAPTCHA instance
                recaptchaContainer.innerHTML = '';

                // Initialize RecaptchaVerifier
                window.recaptchaVerifier = new RecaptchaVerifier(auth, "recaptcha-container", {
                    size: "invisible",
                });
                return window.recaptchaVerifier;
            } catch (error) {
                console.error("Error initializing RecaptchaVerifier:", error.message);
                return null; // Return null if error occurs during initialization
            }
        }
        return window.recaptchaVerifier;
    };

    useEffect(() => {
        generateRecaptcha();

        return () => {
            // Clean up recaptcha container and verifier when component unmounts
            const recaptchaContainer = document.getElementById("recaptcha-container");
            if (recaptchaContainer) {
                recaptchaContainer.innerHTML = "";
            }
            if (window.recaptchaVerifier) {
                window.recaptchaVerifier.clear();
                window.recaptchaVerifier = null; // Clear the recaptchaVerifier reference
            }
        };
    }, []); // Empty dependency array ensures this effect runs only once after mount


    const sendOTP = async () => {
        setShowLoader(true)
        const PhoneNumber = `${countryCode}${formattedNumber}`;
        try {
            const appVerifier = generateRecaptcha();
            const confirmation = await signInWithPhoneNumber(auth, PhoneNumber, appVerifier);
            setConfirmationResult(confirmation);
            toast.success(t("otpSentSuccess"));
            if (isDemoMode) {
                setOtp("123456")

            }
            if (resendOtpLoader) {
                setResendOtpLoader(false)
            }
        } catch (error) {
            const errorCode = error.code;
            handleFirebaseAuthError(errorCode);
            if (resendOtpLoader) {
                setResendOtpLoader(false)
            }
        } finally {
            setShowLoader(false);
        }

    };

    const resendOtp = async (e) => {
        e.preventDefault()
        setResendOtpLoader(true)
        const PhoneNumber = `${countryCode}${formattedNumber}`;
        try {
            const appVerifier = generateRecaptcha();
            const confirmation = await signInWithPhoneNumber(auth, PhoneNumber, appVerifier);
            setConfirmationResult(confirmation);
            toast.success(t("otpSentSuccess"));
            setResendOtpLoader(false)
        } catch (error) {
            const errorCode = error.code;
            handleFirebaseAuthError(errorCode);
            setResendOtpLoader(false)
        }
    }

    const verifyOTP = async (e) => {
        e.preventDefault();

        try {
            if (otp === '') {
                toast.error(t('otpmissing'))
                return
            }
            setShowLoader(true)
            const result = await confirmationResult.confirm(otp);
            // Access user information from the result
            const user = result.user;

            try {
                const response = await userSignUpApi.userSignup({
                    mobile: formattedNumber,
                    firebase_id: user.uid, // Accessing UID directly from the user object
                    fcm_id: fetchFCM ? fetchFCM : "",
                    country_code: countryCode,
                    type: "phone"
                });

                const data = response.data;
                loadUpdateData(data)
                toast.success(data.message);
                if (pathname !== '/home') {
                    if (data?.data?.email === "") {
                        router.push('/profile/edit-profile')
                    }
                }
                setShowLoader(false)
                OnHide();
            } catch (error) {
                console.error("Error:", error);
                setShowLoader(false)
            }
            // Perform necessary actions after OTP verification, like signing in
        } catch (error) {
            const errorCode = error.code;
            handleFirebaseAuthError(errorCode);
            setShowLoader(false)
        }
    };


    const handleLoginSubmit = (e) => {
        setShowLoader(true)
        e.preventDefault();
        if (inputType === "email") {
            setIsPasswordScreen(true);
            setIsLoginScreen(false);
            setShowLoader(false)
        } else if (inputType === "number") {
            // Perform phone number validation on the formatted number
            if (isValidPhoneNumber(`${countryCode}${formattedNumber}`)) {
                sendOTP();
                setIsOTPScreen(true);
                setIsLoginScreen(false);
            } else {
                // Show an error message indicating that the phone number is not valid
                toast.error(t("invalidPhoneNumber"));
                setShowLoader(false)
            }
        } else {
            setShowLoader(false)
            if (email_authentication === 0 && mobile_authentication === 1) {
                toast.error(t("invalidPhoneNumber"));
            } else {
                toast.error(t("invalidPhoneNumberOrEmail"));
            }

        }
    };

    useEffect(() => {
    }, [inputValue, inputType, IsPasswordScreen, IsOTPScreen, email, password, number])

    useEffect(() => {
        if (inputValue === "" && email_authentication === 1) {
            setInputType("email")
            setNumber("")
        }
    }, [inputValue, inputType])

    const togglePasswordVisible = () => {
        setIsPasswordVisible((prev) => !prev)
    }

    const handleShowLoginPassword = () => {
        setIsPasswordScreen(false)
        setIsOTPScreen(false)
        setIsLoginScreen(true)
    }
    const CloseIcon = <div className="close_icon_cont"><MdClose size={24} color="black" /></div>
    const recaptchaClear = async () => {
        const recaptchaContainer = document.getElementById('recaptcha-container')
        if (recaptchaContainer) {
            recaptchaContainer.innerHTML = ''
        }
        if (window.recaptchaVerifier) {
            window?.recaptchaVerifier?.recaptcha?.reset()
        }
    }

    const handleGoogleSignup = async () => {
        const provider = new GoogleAuthProvider();
        try {
            const response = await signInWithPopup(auth, provider);
            const user = response.user
            try {
                const response = await userSignUpApi.userSignup({
                    name: user.displayName ? user.displayName : "",
                    email: user?.email,
                    firebase_id: user.uid, // Accessing UID directly from the user object
                    fcm_id: fetchFCM ? fetchFCM : "",
                    type: "google"
                });

                const data = response.data;
                loadUpdateData(data)
                if (data.error === true) {
                    toast.error(data.message);
                }
                else {
                    toast.success(data.message);
                }
                OnHide();
                if (pathname !== "/home") {
                    if (data?.data?.mobile === "" || data?.data?.mobile === "undefined" || data?.data?.mobile === null) {
                        router.push('/profile/edit-profile')
                    }
                }
            } catch (error) {
                console.error("Error:", error);
            }
        } catch (error) {
            const errorCode = error.code;
            handleFirebaseAuthError(errorCode);
        }
    };


    const handleForgotModal = async e => {
        e.preventDefault()
        const auth = getAuth()
        await sendPasswordResetEmail(auth, email)
            .then(userCredential => {
                toast.success(t('resetPassword'))
                setIsMailSentOpen(true)
                setIsLoginScreen(true)
                setIsPasswordScreen(false)
            })
            .catch(error => {
                const errorCode = error.code;
                handleFirebaseAuthError(errorCode);
            })
    }

    const toggleAuthModal = () => {
        setIsRegisterModalOpen((prev) => !prev);
        if (inputType === 'number') {
            setNumber((prev) => prev.slice(0, countryCodeDigitsOnly.length));
        }
        else {
            setInputValue('')
        }
    };



    return (
        <>
            <Modal
                centered
                open={IsLoginModalOpen}
                closeIcon={CloseIcon}
                colorIconHover="transparent"
                className="ant_register_modal"
                onCancel={OnHide}
                footer={null}
                maskClosable={false}
            >
                {IsLoginScreen && (
                    <div className="register_modal">
                        <div className="reg_modal_header">
                            {
                                mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1 ?
                                    <>
                                        <h1 className="reg_modal_title">
                                            {
                                                IsRegisterModalOpen ? t('welcomeTo') : t('loginTo')
                                            }
                                            <span className="brand_name"> {settings?.company_name}</span>
                                        </h1>
                                        {
                                            IsRegisterModalOpen ?
                                                <p className="signin_redirect">{t('haveAccount')} <span className="main_signin_redirect" onClick={toggleAuthModal}>{t('logIn')}</span></p>
                                                :
                                                <p className="signin_redirect">
                                                    {t('newto')} {settings?.company_name}? {' '}
                                                    <span className="main_signin_redirect" onClick={toggleAuthModal}>
                                                        {t('createAccount')}
                                                    </span>
                                                </p>
                                        }

                                    </>
                                    :
                                    <>
                                        <h1 className="reg_modal_title">
                                            {
                                                IsRegisterModalOpen ? t('welcomeTo') : t('loginTo')
                                            }
                                            <span className="brand_name"> {settings?.company_name}</span>
                                        </h1>
                                        {
                                            IsRegisterModalOpen ?
                                                <p className="signin_redirect">{t('haveAccount')} <span className="main_signin_redirect" onClick={toggleAuthModal}>{t('logIn')}</span></p>
                                                :
                                                <p className="signin_redirect">
                                                    {t('newto')} {settings?.company_name}? {' '}
                                                    <span className="main_signin_redirect" onClick={toggleAuthModal}>
                                                        {t('createAccount')}
                                                    </span>
                                                </p>
                                        }
                                    </>
                            }
                        </div>

                        {
                            !(mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1) &&
                            <form className="auth_form" onSubmit={handleLoginSubmit}>
                                <div className="auth_in_cont">

                                    {
                                        mobile_authentication === 1 && email_authentication === 1 && (
                                            <>
                                                <label htmlFor="email" className="auth_label">
                                                    {t('emailOrPhoneNumber')}
                                                </label>
                                                {inputType === "number" ? (
                                                    <PhoneInput
                                                        country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
                                                        value={number}
                                                        onChange={(phone, data) => handleInputChange(phone, data)}
                                                        onCountryChange={(code) => setCountryCode(code)}
                                                        inputProps={{
                                                            name: "phone",
                                                            required: true,
                                                            autoFocus: true,
                                                        }}
                                                        enableLongNumbers
                                                    />
                                                ) : (
                                                    <input
                                                        type="text"
                                                        className="auth_input"
                                                        placeholder={t("enterEmailPhone")}
                                                        value={inputValue}
                                                        onChange={(e) => handleInputChange(e.target.value, {})}
                                                        required
                                                    />
                                                )}
                                            </>
                                        )
                                    }

                                    {email_authentication === 1 && mobile_authentication === 0 && (
                                        <>
                                            <label htmlFor="email" className="auth_label">
                                                {t('email')}
                                            </label>
                                            <input
                                                type="email"
                                                className="auth_input"
                                                placeholder={t("enterEmail")}
                                                value={inputValue}
                                                onChange={(e) => handleInputChange(e.target.value)}
                                                required
                                            />
                                        </>
                                    )}

                                    {mobile_authentication === 1 && email_authentication === 0 && (
                                        <>
                                            <label htmlFor="phone" className="auth_label">
                                                {t('phoneNumber')}
                                            </label>
                                            <PhoneInput
                                                country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
                                                value={number}
                                                onChange={(phone, data) => handleInputChange(phone, data)}
                                                onCountryChange={(code) => setCountryCode(code)}
                                                inputProps={{
                                                    name: "phone",
                                                    required: true,
                                                    autoFocus: true,
                                                }}
                                            />
                                        </>
                                    )}
                                </div>

                                {
                                    !(mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1) &&
                                    <button type="submit" className="verf_email_add_btn">
                                        {showLoader ? (
                                            <div className="loader-container-otp">
                                                <div className="loader-otp"></div>
                                            </div>
                                        ) : (
                                            <span>{t('continue')}</span>
                                        )}
                                    </button>
                                }
                            </form>
                        }



                        {
                            !(mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1) && google_authentication === 1 &&
                            <div className="signup_with_cont">
                                <hr />
                                <p>{t('orSignInWith')}</p>
                                <hr />
                            </div>
                        }

                        {
                            google_authentication === 1 &&
                            <button className="reg_with_google_btn" onClick={handleGoogleSignup}>
                                <FcGoogle size={24} />
                                {t('google')}
                            </button>
                        }

                        <div className="auth_modal_footer">
                            {t('agreeSignIn')} {settings?.company_name} <br />
                            <Link href="/terms-and-condition" className="link_brand_name" onClick={OnHide}>
                                {t('termsService')}
                            </Link>{" "}
                            {t('and')}{" "}
                            <Link href="/privacy-policy" className="link_brand_name" onClick={OnHide}>
                                {t('privacyPolicy')}
                            </Link>
                        </div>
                    </div>
                )}


                {IsPasswordScreen && (
                    <div className="register_modal">
                        <div className="reg_modal_header">


                            <h1 className="reg_modal_title">{IsRegisterModalOpen ? t('signUpWithEmail') : t('signInWithEmail')}</h1>
                            <p className="signin_redirect">
                                {email}{" "}
                                <span className="main_signin_redirect" onClick={handleShowLoginPassword}>
                                    {t('change')}
                                </span>
                            </p>
                        </div>
                        <form className="auth_form" onSubmit={Signin}>
                            {
                                IsRegisterModalOpen &&
                                <div className="auth_in_cont">
                                    <label htmlFor="username" className="auth_label">{t('username')}</label>
                                    <input type="text" placeholder={t("typeUsername")} className="auth_input" name="username" required onChange={(e) => setUsername(e.target.value)} value={username} />

                                </div>
                            }


                            <div className="auth_in_cont">
                                <label htmlFor="password" className="auth_label">
                                    {t('password')}
                                </label>
                                <div className="password_cont">
                                    <input
                                        type={IsPasswordVisible ? "text" : "password"}
                                        className="auth_input"
                                        placeholder={t("enterPassword")}
                                        id="password"
                                        name="password"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                    />
                                    <div className="pass_eye" onClick={togglePasswordVisible}>
                                        {IsPasswordVisible ? <FaRegEye size={20} /> : <FaRegEyeSlash size={20} />}
                                    </div>
                                </div>
                            </div>
                            {
                                !IsRegisterModalOpen &&
                                <p className="frgt_pass" onClick={handleForgotModal}>{t('forgtPassword')}</p>
                            }
                            <button type="submit" className="verf_email_add_btn">
                                {showLoader ? (
                                    <div className="loader-container-otp">
                                        <div className="loader-otp"></div>
                                    </div>
                                ) : (
                                    IsRegisterModalOpen ? <span>{t('verifyEmail')}</span> : <span>{t('signIn')}</span>
                                )}
                            </button>
                        </form>
                    </div>
                )}
                {IsOTPScreen && (
                    <>
                        <div className="register_modal">
                            <div className="reg_modal_header">
                                <h1 className="reg_modal_title">{t('verifyOtp')}</h1>
                                <p className="signin_redirect">
                                    {t('sentTo')} {`+${number}`}{" "}
                                    <span className="main_signin_redirect" onClick={handleShowLoginPassword}>
                                        {t('change')}
                                    </span>
                                </p>
                            </div>
                            <form className="auth_form">
                                <div className="auth_in_cont">
                                    <label htmlFor="otp" className="auth_label">
                                        {t('otp')}
                                    </label>
                                    <input
                                        type="text"
                                        className="auth_input"
                                        placeholder={t("enterOtp")}
                                        id="otp"
                                        name="otp"
                                        value={otp}
                                        maxLength="6"
                                        onChange={(e) => setOtp(e.target.value)}
                                    />
                                </div>
                                <>

                                    {showLoader ? (
                                        <div className="loader-container-otp">
                                            <div className="loader-otp"></div>
                                        </div>
                                    ) : (
                                        <button type="submit" className="verf_email_add_btn" onClick={verifyOTP}>
                                            {t('verify')}
                                        </button>
                                    )}

                                    {
                                        resendOtpLoader ? (
                                            <div className="loader-container-otp">
                                                <div className="loader-otp"></div>
                                            </div>
                                        )
                                            :
                                            (
                                                <button type="submit" className="resend_otp_btn" onClick={resendOtp}>
                                                    {t('resendOtp')}
                                                </button>
                                            )
                                    }

                                </>
                            </form>
                        </div>
                    </>
                )}
            </Modal>
            <div id="recaptcha-container"></div>
            <MailSentSucessfully IsMailSentOpen={IsMailSentOpen} OnHide={() => setIsMailSentOpen(false)} IsLoginModalOpen={() => setIsLoginModalOpen(true)} />
        </>
    )
}

export default LoginModal