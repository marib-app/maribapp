import { placeholderImage, t } from '@/utils';
import { Modal } from 'antd';
import Image from 'next/image';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { FaAngleRight } from 'react-icons/fa6';
import { MdClose } from 'react-icons/md';
import stripe from '../../../../public/assets/ic_stripe.png';
import razorpay from '../../../../public/assets/ic_razorpay.png';
import paystack from '../../../../public/assets/ic_paystack.png';
import phonepay from '../../../../public/assets/phonepe-icon.png'
import useRazorpay from 'react-razorpay';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import { createPaymentIntentApi } from '@/utils/api';
import { loadStripe } from '@stripe/stripe-js';
import { Elements, ElementsConsumer, elements } from '@stripe/react-stripe-js'; // Corrected line
import { CardElement } from '@stripe/react-stripe-js';


const PaymentModal = ({ isPaymentModal, OnHide, packageSettings, priceData, settingsData, user, setItemPackages, setAdvertisementPackage }) => {
    const router = useRouter();

    const [stripePromise, setStripePromise] = useState('')

    const PayStackActive = packageSettings?.Paystack;
    const RazorPayActive = packageSettings?.Razorpay;
    const StripeActive = packageSettings?.Stripe;
    const PhonepayActive = packageSettings?.PhonePe;

    // const stripePromise = loadStripe(packageSettings?.Stripe?.api_key);
    const [showStripeForm, setShowStripeForm] = useState(false);
    const [clientSecret, setClientSecret] = useState("");

    const PaymentModalClose = () => {
        OnHide()
        setShowStripeForm(false)
    }
    useEffect(() => {
    }, [showStripeForm, clientSecret])

    useEffect(() => {
        const loadStripeInstance = async () => {
            if (packageSettings?.Stripe?.api_key) {
                const stripeInstance = await loadStripe(packageSettings.Stripe.api_key);
                setStripePromise(stripeInstance);
            }
        };
        loadStripeInstance();
    }, [packageSettings]);

    const CloseIcon = <div className="close_icon_cont"><MdClose size={24} color="black" /></div>;

    const updateActivePackage = () => {
        if (priceData.type === 'advertisement') {

            setAdvertisementPackage((prev) => {
                return prev.map(item => {
                    if (item.id === priceData.id) {
                        return { ...item, is_active: true };
                    }
                    return item;
                });
            });

        } else if (priceData.type === 'item_listing') {
            setItemPackages((prev) => {
                return prev.map(item => {
                    if (item.id === priceData.id) {
                        return { ...item, is_active: true };
                    }
                    return item;
                });
            });
        }
        toast.success(t('paymentSuccess'));
    }

    const handleOpenStripeModal = () => {
        setShowStripeForm(true)
    }
    const [Razorpay, isLoaded] = useRazorpay();
    let rzpay; // Define rzpay outside the function

    const PayWithRazorPay = useCallback(async () => {
        try {
            const res = await createPaymentIntentApi.createIntent({ package_id: priceData.id, payment_method: RazorPayActive.payment_method });
            if (res.data.error) {
                toast.error(res.data.message)
                return
            }
            OnHide()
            const paymentIntent = res.data.data.payment_intent;
            const options = {
                key: RazorPayActive.api_key,
                name: settingsData.company_name,
                description: settingsData.company_name,
                image: settingsData.company_logo,
                order_id: paymentIntent.id,
                handler: function (response) {
                    updateActivePackage()
                },
                prefill: {
                    name: user.name,
                    email: user.email,
                    contact: user.mobile,
                },
                notes: {
                    address: user.address,
                    user_id: user.id,
                    package_id: priceData.id,
                },
                theme: {
                    color: settingsData.web_theme_color,
                },
            };

            rzpay = new Razorpay(options); // Assign rzpay outside the function

            rzpay.on('payment.failed', function (response) {
                console.error(response.error.description);
                toast.error(response.error.description);
                if (rzpay) {
                    rzpay?.close(); // Close the Razorpay payment modal
                }
            });

            rzpay.on('payment.modal.closed', function () {
                toast(t('paymentMClose'));
            });

            rzpay.open();
        } catch (error) {
            console.error("Error during payment", error);
            toast.error(t("errorProcessingPayment"));
        }
    }, [RazorPayActive, priceData, settingsData, user, router]);


    const paymentReferenceRef = useRef(null);
    const paymentPopupRef = useRef(null);

    const handlePayStackPayment = useCallback(async () => {
        try {
            const res = await createPaymentIntentApi.createIntent({ package_id: priceData.id, payment_method: PayStackActive.payment_method, platform_type: 'web' });

            if (res.data.error) {
                throw new Error(res.data.message);
            }

            const paymentIntent = res.data.data.payment_intent;
            const authorizationUrl = paymentIntent?.payment_gateway_response?.data?.authorization_url;
            // const authorizationUrl = '/paystack-popup.html';
            const reference = paymentIntent?.payment_gateway_response?.data?.reference;

            paymentReferenceRef.current = reference;

            if (authorizationUrl) {
                const popupWidth = 600;
                const popupHeight = 700;
                const popupLeft = (window.innerWidth / 2) - (popupWidth / 2);
                const popupTop = (window.innerHeight / 2) - (popupHeight / 2);

                const paymentPopup = window.open(authorizationUrl, 'paymentWindow', `width=${popupWidth},height=${popupHeight},top=${popupTop},left=${popupLeft}`);
                paymentPopupRef.current = paymentPopup;

                const handleMessage = (event) => {
                    if (event.origin === process.env.NEXT_PUBLIC_API_URL) {
                        const { status, reference } = event.data;
                        if (status === 'success' && reference === paymentReferenceRef.current) {
                            updateActivePackage()
                            PaymentModalClose();
                        } else {
                            toast.error(t("paymentFailed"));
                            PaymentModalClose();
                        }
                    }
                };

                window.addEventListener('message', handleMessage);

                return () => {
                    window.removeEventListener('message', handleMessage);
                };
            } else {
                throw new Error("Unable to retrieve authorization URL.");
            }
        } catch (error) {
            console.error("An error occurred while processing the payment:", error);
            toast.error(t("errorOccurred"));
        }
    }, [PayStackActive, priceData, user, router, OnHide]);

    const handleStripePayment = useCallback(async () => {
        try {
            const res = await createPaymentIntentApi.createIntent({ package_id: priceData.id, payment_method: StripeActive.payment_method });
            if (res.data.error) {
                toast.error(res.data.message);
                return
            }
            const paymentIntent = res.data.data.payment_intent?.payment_gateway_response;
            const clientSecret = paymentIntent.client_secret;
            setClientSecret(clientSecret)
            handleOpenStripeModal()

        } catch (error) {
            console.error("Error during Stripe payment", error);
            toast.error(t("errorOccurred"));
        }
    }, [StripeActive, priceData, showStripeForm]);

    // Define PaymentForm component to handle Stripe payment
    const PaymentForm = ({ elements }) => {
        const handleSubmit = async (event) => {
            event.preventDefault();

            // Retrieve Stripe instance from stripePromise
            const stripe = stripePromise;


            // Create payment method using CardElement
            const { error, paymentMethod } = await stripe.createPaymentMethod({
                type: 'card',
                card: elements.getElement(CardElement),
            });

            // Handle payment response
            if (error) {
                // Handle error here
            } else {
                try {
                    // Confirm the payment with the client secret

                    const { paymentIntent, error: confirmError } = await stripe.confirmCardPayment(clientSecret, {
                        payment_method: paymentMethod.id,
                    });

                    if (confirmError) {
                        // Handle confirm error here
                    } else {
                        if (paymentIntent.status === 'succeeded') {
                            // Payment successful
                            updateActivePackage()
                            PaymentModalClose()
                            // Handle successful payment here
                        } else {
                            // Payment failed
                            toast.error(t('paymentfail ' + paymentIntent.status));
                            // Handle failed payment here
                        }
                    }
                } catch (error) {
                    console.error('Error during payment:', error);
                    // Handle general error here
                }
            }
        };

        return (
            <form onSubmit={handleSubmit}>
                <div className="stripe_module">
                    <CardElement />
                    <button className='stripe_pay' type="submit" disabled={!stripePromise}>
                        {t('pay')}
                    </button>
                </div>
            </form>
        );
    };



    const handlePhonepePayment = async () => {

        try {
            const res = await createPaymentIntentApi.createIntent({ package_id: priceData.id, payment_method: PhonepayActive.payment_method });
            if (res.data.error) {
                toast.error(res.data.message);
                OnHide()
                return
            }

            const payment_gateway_response = res.data.data.payment_intent.payment_gateway_response;

            if (payment_gateway_response) {

                const popupWidth = 600;
                const popupHeight = 700;
                const popupLeft = (window.innerWidth / 2) - (popupWidth / 2);
                const popupTop = (window.innerHeight / 2) - (popupHeight / 2);

                window.open(payment_gateway_response, 'paymentWindow', `width=${popupWidth},height=${popupHeight},top=${popupTop},left=${popupLeft}`);
            }

            const handleMessage = (event) => {
                if (event.origin === 'https://eclassify.thewrteam.in') {
                    const { status } = event.data;
                    if (status === 'success') {
                        updateActivePackage()
                        PaymentModalClose();
                    } else {
                        toast.error(t("paymentFailed"));
                        PaymentModalClose();
                    }
                }
            };

            window.addEventListener('message', handleMessage);

            return () => {
                window.removeEventListener('message', handleMessage);
            };

        } catch (error) {
            console.error("Error during Stripe payment", error);
            toast.error(t("errorOccurred"));
        }
    }


    return (
        <>
            <Modal
                centered
                open={isPaymentModal}
                closeIcon={CloseIcon}
                colorIconHover='transparent'
                className="ant_payment_modal"
                onCancel={PaymentModalClose}
                footer={null}
                maskClosable={false}
            >
                <div className="payment_section">
                    {showStripeForm ? (
                        <div className="card">
                            <div className="card-header">
                                {t('payWithStripe')} :
                            </div>
                            <div className="card-body">
                                <Elements stripe={stripePromise}
                                // client_key={StripeActive?.api_key} 
                                >
                                    <ElementsConsumer>
                                        {({ stripe, elements }) => (
                                            <PaymentForm elements={elements} stripe={stripe} />
                                        )}
                                    </ElementsConsumer>
                                </Elements>
                            </div>
                        </div>
                    ) : (
                        <div className="card">
                            <div className="card-header">
                                <span>
                                    {t('paymentWith')}
                                </span>
                            </div>
                            <div className="card-body">
                                <div className="row">
                                    {StripeActive?.status === 1 &&
                                        <div className="col-12">
                                            <button onClick={handleStripePayment}>
                                                <div className="payment_details">
                                                    <Image loading='lazy' src={stripe} onEmptiedCapture={placeholderImage} />
                                                    <span>
                                                        {t('stripe')}
                                                    </span>
                                                </div>
                                                <div className="payment_icon">
                                                    <FaAngleRight size={18} />
                                                </div>
                                            </button>
                                        </div>
                                    }
                                    {RazorPayActive?.status === 1 &&
                                        <div className="col-12">
                                            <button onClick={PayWithRazorPay}>
                                                <div className="payment_details">
                                                    <Image loading='lazy' src={razorpay} onEmptiedCapture={placeholderImage} />
                                                    <span>
                                                        {t('razorPay')}
                                                    </span>
                                                </div>
                                                <div className="payment_icon">
                                                    <FaAngleRight size={18} />
                                                </div>
                                            </button>
                                        </div>
                                    }
                                    {PayStackActive?.status === 1 &&
                                        <div className="col-12">
                                            <button onClick={handlePayStackPayment}>
                                                <div className="payment_details">
                                                    <Image loading='lazy' src={paystack} onEmptiedCapture={placeholderImage} />
                                                    <span>
                                                        {t('payStack')}
                                                    </span>
                                                </div>
                                                <div className="payment_icon">
                                                    <FaAngleRight size={18} />
                                                </div>
                                            </button>
                                        </div>
                                    }
                                    {PhonepayActive?.status === 1 &&
                                        <div className="col-12">
                                            <button onClick={handlePhonepePayment}>
                                                <div className="payment_details">
                                                    <Image loading='lazy' src={phonepay} onEmptiedCapture={placeholderImage} width={30} height={30} />
                                                    <span>
                                                        {t('phonepe')}
                                                    </span>
                                                </div>
                                                <div className="payment_icon">
                                                    <FaAngleRight size={18} />
                                                </div>
                                            </button>
                                        </div>
                                    }
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </Modal>
        </>
    );
};

export default PaymentModal;
