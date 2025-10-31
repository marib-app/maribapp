'use client'
import { useEffect, useRef, useState } from 'react';
import { IoCloseCircleOutline, IoGiftOutline } from "react-icons/io5";
import { IoMdAttach } from "react-icons/io";
import ProfileSidebar from "@/components/Profile/ProfileSidebar";
import { BiSend } from "react-icons/bi";
import { formatPriceAbbreviated, t } from "@/utils";
import { addItemReviewApi, blockUserApi, getMessagesApi, itemOfferApi, sendMessageApi, tipsApi, unBlockUserApi } from '@/utils/api';
import { useSelector } from 'react-redux';
import toast from 'react-hot-toast';
import NoChatFound from '@/components/NoDataFound/NoChatFound';
import { Rate } from 'antd';
import ImageViewer from './ImageViewer';
import BreadcrumbComponent from '@/components/Breadcrumb/BreadcrumbComponent';
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice';
import NoConvWithSeller from './NoConvWithSeller';
import MakeOfferInChat from './MakeOfferInChat';
import TipsModal from './TipsModal';
import ChatList from './ChatList';
import ChatUserTab from './ChatUserTab';
import ChatMessages from './ChatMessages';
import { saveOfferData } from '@/redux/reuducer/offerSlice';


const Chat = ({ setActiveTab, activeTab, chatMessages, setChatMessages, selectedTabData, setSelectedTabData, defaultSelected }) => {

    const CurrentLanguage = useSelector(CurrentLanguageData)
    const systemSettingsData = useSelector((state) => state?.Settings)
    const CurrencySymbol = systemSettingsData?.data?.data?.currency_symbol
    const [blockedUsersList, setBlockedUsersList] = useState([]);
    const [blockPopoverVisible, setBlockPopoverVisible] = useState(false);
    const [popoverVisible, setPopoverVisible] = useState(false);
    const [isUserOffer, setIsUSerOffer] = useState(false); // State to store selected chat IDD
    const [messageInput, setMessageInput] = useState(''); // State to store text message
    const [selectedFile, setSelectedFile] = useState(null); // State to store selected file
    const [selectedFilePreview, setSelectedFilePreview] = useState(null);
    const [isBlocked, setIsBlocked] = useState(false); // State to hold
    const [viewerImage, setViewerImage] = useState(null);
    const [isSending, setIsSending] = useState(false);
    const [Rating, setRating] = useState('')
    const [IsTopMakeOffer, setIsTopMakeOffer] = useState(true)
    const [IsMakeOfferInChat, setIsMakeOfferInChat] = useState(false)
    const [OfferPrice, setOfferPrice] = useState('')
    const [Review, setReview] = useState('')
    const [IsTipsOpen, setIsTipsOpen] = useState(false)
    const [tipsData, setTipsData] = useState([])
    const makeUnableToChat = selectedTabData?.item?.status === "review" || selectedTabData?.item?.status === "rejected" || selectedTabData?.item?.status === "sold out" || selectedTabData?.item?.status === "inactive"
    const IsShowRating = activeTab === 'buying' && selectedTabData?.item?.status === "sold out"
    const IsShowMakeOfferOnTop = IsTopMakeOffer && chatMessages?.length > 0 && !selectedTabData?.amount && !makeUnableToChat && activeTab === 'buying'
    const IsShowInitialMakeOffer = chatMessages?.length === 0 && !selectedTabData?.amount && !IsMakeOfferInChat && activeTab === 'buying' && !makeUnableToChat
    const IsShowOfferInput = IsMakeOfferInChat && activeTab === 'buying' && !selectedTabData?.amount && !makeUnableToChat
    const [IsSubmittingOffer, setIsSubmittingOffer] = useState(false)
    const [buyerChatList, setBuyerChatList] = useState([]);
    const [IsLoadPrevMesg, setIsLoadPrevMesg] = useState(false)
    const [CurrentMessagesPage, setCurrentMessagesPage] = useState(1)
    const [HasMoreChatMessages, setHasMoreChatMessages] = useState(false)



    useEffect(() => {
        if (activeTab === "buying") {
            setIsUSerOffer(true)
        } else {
            setIsUSerOffer(false)
        }
    }, [activeTab]);



    // Function to fetch blocked users

    const handleUnBlockUser = async (id) => {
        try {
            const response = await unBlockUserApi.unBlockUser({ blocked_user_id: id });
            if (response?.data.error === false) {
                setSelectedTabData((prevData) => ({
                    ...prevData,
                    user_blocked: false
                }));
                setBlockedUsersList(prevUsers => prevUsers.filter(user => user.id !== id));
                setIsBlocked(false);

                // close popovers
                setBlockPopoverVisible(false)
                setPopoverVisible(false)


                toast.success(response?.data?.message);
            } else {
                toast.error(response?.data?.message);
            }
        } catch (error) {
            setIsBlocked(true);
            console.log(error);
        }
    };

    const handleBlockUser = async (id) => {
        try {
            const response = await blockUserApi.blockUser({ blocked_user_id: id });
            if (response?.data?.error === false) {
                setIsBlocked(true);
                setSelectedTabData((prevData) => ({
                    ...prevData,
                    user_blocked: true
                }));
                setPopoverVisible(false);
                setBlockPopoverVisible(false)
                toast.success(response?.data?.message);
            }
            else {
                toast.error(response?.data?.message);
            }
        } catch (error) {
            setIsBlocked(false);
            console.log(error);
        }
    };

    const fetchChatMessgaes = async (id, page = 1) => {
        try {
            if (page > 1) {
                setIsLoadPrevMesg(true)
            }
            const response = await getMessagesApi.chatMessages({ item_offer_id: id, page });
            const { data } = response.data;


            if (page === 1) {
                setChatMessages(data?.data);
            }
            else {
                setChatMessages((prev) => [...prev, ...data?.data]);
            }
            setCurrentMessagesPage(data?.current_page)

            if (Number(data?.current_page) < Number(data?.last_page)) {
                setHasMoreChatMessages(true)
            }
            else {
                setHasMoreChatMessages(false)
            }
            setOfferPrice('')
            setRating('')
        } catch (error) {
            console.log(error);
        } finally {
            setIsLoadPrevMesg(false)
        }
    };


    useEffect(() => {
        setSelectedTabData(defaultSelected)
        if (defaultSelected) {
            fetchChatMessgaes(defaultSelected?.id);
        }
    }, [defaultSelected]);


    const fetchTipsData = async () => {
        try {
            const response = await tipsApi.tips({})
            const { data } = response.data
            if (data.length > 0) {
                setTipsData(data)
            }

        } catch (error) {
            console.log(error)
        }
    }

    useEffect(() => {
        if (!selectedTabData?.amount) {
            fetchTipsData()
        }
    }, [])

    useEffect(() => {
        if (selectedTabData?.user_blocked === true) {
            setIsBlocked(true)
        } else {
            setIsBlocked(false)
        }

    }, [selectedTabData])

    const handleFileChange = (e) => {
        const file = e.target.files[0];
        if (file) {
            const validTypes = ['image/jpeg', 'image/png', 'image/jpg'];
            if (validTypes.includes(file.type)) {
                setSelectedFile(file);
                const reader = new FileReader();
                reader.onloadend = () => {
                    setSelectedFilePreview(reader.result);
                };
                reader.readAsDataURL(file);
            } else {
                // Reset the input field
                e.target.value = null;
                setSelectedFilePreview(null);
                // Show an error message
                toast.error(t('selectValidImage'));
            }
        } else {
            // Reset the input field
            e.target.value = null;
            setSelectedFilePreview(null);
        }
    };


    const openImageViewer = (imageSrc) => {
        setViewerImage(imageSrc);
    };

    const handleKeyDown = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault(); // Prevent default behavior (new line)
            sendMessage();
        }
    };

    const sendMessage = async () => {
        setIsSending(true);
        try {
            const response = await sendMessageApi.sendMessage({
                item_offer_id: selectedTabData?.id,
                message: messageInput ? messageInput : "",
                file: selectedFile ? selectedFile : "",
            });
            const { data } = response.data;
            if (response?.data?.error === false) {
                setChatMessages((prevMessages) => [data, ...prevMessages]);
                setMessageInput('');
                setSelectedFile(null);
                setSelectedFilePreview(null);
                if (!selectedTabData?.amount) {
                    setIsTopMakeOffer(true)
                }
            } else {
                toast.error(response?.data?.message)
            }
        } catch (error) {
            console.log(error);

        } finally {
            setIsSending(false);
        }
    };

    const handleRatingChange = (value) => {
        setRating(value)
    }

    const handleMakeOfferInStart = () => {

        if (tipsData.length > 0) {
            setIsTipsOpen(true)
        }
        else {
            setIsMakeOfferInChat(true)
        }
    }

    const handleOfferLaterClick = () => {
        setIsMakeOfferInChat(false)
        if (chatMessages?.length > 0 && !selectedTabData?.amount) {
            setIsTopMakeOffer(true)
        }
    }

    const handleTopMakeOfferClick = () => {
        if (tipsData.length > 0) {
            setIsTipsOpen(true)
        }
        else {
            setIsMakeOfferInChat(true)
            setIsTopMakeOffer(false)
        }
    }

    const handleSendOffer = async () => {
        // Ensure the offer price is a valid number
        const offerAmount = parseFloat(OfferPrice);

        if (isNaN(offerAmount) || offerAmount <= 0) {
            toast.error(t('offerPricePositiveError')); // Set an error message if the offer price is not valid
            return;
        }

        if (offerAmount > selectedTabData?.item?.price) {
            toast.error(t('offerPriceError')); // Set an error message if the offer price is too high
            return;
        }

        try {
            setIsSubmittingOffer(true)
            const response = await itemOfferApi.offer({
                item_id: Number(selectedTabData.item_id),
                amount: offerAmount
            });
            const { data } = response.data;

            if (response?.data?.error === false) {
                toast.success(response?.data?.message);
                setIsMakeOfferInChat(false)
                setBuyerChatList((prev) =>
                    prev.map((item) => {
                        if (Number(item.id) === Number(response?.data?.data?.id)) {
                            return response?.data?.data; // Update the matching item
                        }
                        return item; // Keep other items unchanged
                    })
                );
                saveOfferData(data)
                setSelectedTabData(data)
                setIsUSerOffer(true)
            }
        } catch (error) {
            console.log(error);
            toast.error(t('offerSendError')); // Handle error during offer sending
        } finally {
            setIsSubmittingOffer(false)
        }
    };


    const handleReviewSubmit = async () => {
        if (Rating === '') {
            toast.error(t('provideRating'))
            return
        }
        if (Review.trim() === '') {
            toast.error(t('provideReview'))
            return
        }
        try {
            const res = await addItemReviewApi.addItemReview({ item_id: selectedTabData?.item_id, review: Review, ratings: Rating })
            if (res?.data?.error === false) {
                toast.success(res?.data?.message)

                setSelectedTabData((prev) => ({
                    ...prev,
                    item: {
                        ...prev.item,
                        review: res?.data?.data,
                    },
                }));

                setBuyerChatList((prev) =>
                    prev.map(chatItem =>
                        chatItem?.item?.id === Number(res?.data?.data?.item_id) // Match item_id correctly
                            ? {
                                ...chatItem,
                                item: {
                                    ...chatItem.item, // Preserve the other properties of the item
                                    review: res?.data?.data?.review // Set review from the response
                                }
                            }
                            : chatItem
                    )
                );
                setReview('')
                setRating('')
            }
            else {
                toast.error(t('failedToSubmitReview'))
            }
        } catch (error) {
            console.log(error)
        }
    }

    const handleReviewChange = (e) => {
        setReview(e.target.value)
    }

    const handleRemoveFile = () => {
        setSelectedFilePreview(null);
        setSelectedFile(null);
        // Reset the input value to allow re-uploading the same file
        document.getElementById('file_attach').value = null;
    };

    return (
        <>
            <BreadcrumbComponent title2={t('chat')} />

            <div className='container'>
                <div className="row">
                    <div className="col-12 my_prop_title_spacing">
                        <h4 className="pop_cat_head">{t('chat')}</h4>
                    </div>
                </div>
                <div className="row profile_sidebar">
                    <ProfileSidebar />
                    <div className="col-lg-9 p-0">
                        <div className="container">
                            <div className="row">
                                <div className="col-lg-4 p-0">
                                    <ChatList systemSettingsData={systemSettingsData} selectedTabData={selectedTabData} setSelectedTabData={setSelectedTabData} activeTab={activeTab} setActiveTab={setActiveTab} setBlockedUsersList={setBlockedUsersList} blockPopoverVisible={blockPopoverVisible} setBlockPopoverVisible={setBlockPopoverVisible} blockedUsersList={blockedUsersList} handleUnBlockUser={handleUnBlockUser} setReview={setReview} setRating={setRating} buyerChatList={buyerChatList} setBuyerChatList={setBuyerChatList} />
                                </div>
                                <div className="col-lg-8 p-0">
                                    {!selectedTabData || selectedTabData?.length <= 0 ? (
                                        <NoChatFound />
                                    ) : (
                                        <div className="chat">

                                            <ChatUserTab activeTab={activeTab} selectedTabData={selectedTabData} systemSettingsData={systemSettingsData} isBlocked={isBlocked} handleBlockUser={handleBlockUser} handleUnBlockUser={handleUnBlockUser} popoverVisible={popoverVisible} setPopoverVisible={setPopoverVisible} />

                                            <div className='chatRatingWrap'>
                                                {
                                                    IsShowMakeOfferOnTop &&
                                                    <div className='topMakeOffer'>
                                                        <h1 className='submitProposal'>{t('submitProposal')}</h1>
                                                        <button className="makeOfferCont" onClick={handleTopMakeOfferClick}>
                                                            <span><IoGiftOutline size={20} /></span>
                                                            <span>{t('makeOffer')}</span>
                                                        </button>
                                                    </div>
                                                }


                                                <>
                                                    {
                                                        IsShowInitialMakeOffer &&
                                                        <NoConvWithSeller key={defaultSelected?.id} handleMakeOfferInStart={handleMakeOfferInStart} />
                                                    }
                                                    {
                                                        (chatMessages?.length > 0 || selectedTabData?.amount) &&
                                                        <div className='render_messages'>

                                                            {
                                                                selectedTabData?.amount &&
                                                                <div className={`${isUserOffer ? "sender_offerprice" : "receiver_offerprice"}`}>
                                                                    <div className="chat_time_cont">
                                                                        <div className="sender_text_cont">
                                                                            {isUserOffer ? (
                                                                                <p className="youroffer">{t('yourOffer')}</p>
                                                                            ) : (
                                                                                <p className="youroffer">{t('offer')}</p>
                                                                            )}
                                                                            <h5>{CurrencySymbol}{formatPriceAbbreviated(selectedTabData?.amount)}</h5>
                                                                        </div>
                                                                    </div>
                                                                </div>

                                                            }

                                                            <ChatMessages key={defaultSelected?.id} chatMessages={chatMessages} selectedTabData={selectedTabData} openImageViewer={openImageViewer} systemSettingsData={systemSettingsData} IsLoadPrevMesg={IsLoadPrevMesg} CurrentMessagesPage={CurrentMessagesPage} HasMoreChatMessages={HasMoreChatMessages} fetchChatMessgaes={fetchChatMessgaes} />

                                                        </div>
                                                    }
                                                </>

                                                {
                                                    IsShowOfferInput &&
                                                    <MakeOfferInChat handleOfferLaterClick={handleOfferLaterClick} OfferPrice={OfferPrice} setOfferPrice={setOfferPrice} handleSendOffer={handleSendOffer} IsSubmittingOffer={IsSubmittingOffer} />
                                                }



                                                {
                                                    IsShowRating && !selectedTabData?.item?.review &&
                                                    <div className='rateSellerWrap'>
                                                        <div className='rateSellerCont'>
                                                            <h6 className='rateSellerHeading'>{t('rateSeller')}</h6>
                                                            <div className="rateExpCont">
                                                                <p className='rateYourExp'>{t('rateYourExp')}</p>
                                                                <Rate defaultValue={0} value={Rating} className='ratingStars' onChange={handleRatingChange} />
                                                                <textarea value={Review} onChange={handleReviewChange} className='auth_input no-resize' id="" cols="30" rows="5" placeholder={t('writeReview')}></textarea>
                                                                <button className='reviewSubmitBtn' onClick={handleReviewSubmit}>{t('submit')}</button>
                                                            </div>
                                                        </div>
                                                    </div>
                                                }
                                            </div>

                                            {makeUnableToChat ? (
                                                <div className='itemStatus'>
                                                    <p>{t("thisitem")} {selectedTabData?.item?.status}</p>
                                                </div>
                                            ) : (
                                                <div className="chat_input_cont" style={{ padding: isBlocked ? "0px" : "16px" }}>
                                                    <input
                                                        type="file"
                                                        id="file_attach"
                                                        className="chat_file_input"
                                                        onChange={handleFileChange}
                                                        accept="image/jpeg,image/png,image/jpg"
                                                        style={{ display: 'none' }}
                                                        disabled={IsShowRating}
                                                    />
                                                    {selectedFilePreview && (
                                                        <div className="file_preview_container">
                                                            <img src={selectedFilePreview} alt="File Preview" className="file_preview_image" />
                                                            <button className="remove_button" onClick={handleRemoveFile}>
                                                                <IoCloseCircleOutline size={18} />
                                                            </button>
                                                        </div>
                                                    )}
                                                    {isBlocked && (
                                                        <div className='blockedText'>
                                                            {activeTab === 'buying' ? (

                                                                <span>
                                                                    {t("youhaveblocked")}{" "}
                                                                    <span className='tap' onClick={() => handleUnBlockUser(selectedTabData?.seller?.id)}>
                                                                        {t("unblock")}.
                                                                    </span>
                                                                </span>
                                                            ) : (
                                                                <span>
                                                                    {t("youhaveblocked")}{" "}
                                                                    <span className='tap' onClick={() => handleUnBlockUser(selectedTabData?.buyer?.id)}>
                                                                        {t("unblock")}.
                                                                    </span>
                                                                </span>
                                                            )}
                                                        </div>
                                                    )}
                                                    <div className="inputs">
                                                        <div className="file_attach_input">
                                                            <label htmlFor="file_attach" className={`file_attach2 ${isBlocked ? 'disabled' : ''}`}>
                                                                <IoMdAttach size={30} className={`file_attach ${IsShowRating && 'cursor_default'}`} />
                                                            </label>
                                                            <textarea
                                                                name="chatmessage"
                                                                id="chatmessage"
                                                                className="chat_message"
                                                                placeholder={IsShowRating ? t("chatIsDisable") : t("typeMessageHere")}
                                                                value={messageInput}
                                                                onChange={(e) => setMessageInput(e.target.value)}
                                                                onKeyDown={handleKeyDown}
                                                                disabled={IsShowRating}
                                                            />
                                                        </div>
                                                        <div className="audio_send_cont">
                                                            {/* {!IsRecording ? (
                                                                <button onClick={handleStartRecording}>
                                                                    <MdKeyboardVoice size={24} color="#595B6C" />
                                                                </button>
                                                            ) : (
                                                                <button onClick={stopRecording}>
                                                                    <BsFillMicMuteFill size={24} color="#595B6C" />
                                                                </button>
                                                            )} */}
                                                            <button
                                                                className="bisend_cont"
                                                                onClick={sendMessage}
                                                                disabled={isBlocked || isSending || (!messageInput && !selectedFile)}
                                                                style={{ opacity: (isBlocked || isSending || (!messageInput && !selectedFile)) ? 0.5 : 1 }}
                                                            >
                                                                <BiSend size={24} color="white" />
                                                            </button>
                                                        </div>
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>
                            </div>

                        </div>
                    </div>
                </div >
                {viewerImage && (
                    <ImageViewer
                        src={viewerImage}
                        alt="Full size image"
                        onClose={() => setViewerImage(null)}
                    />
                )
                }
            </div >
            <TipsModal IsTipsOpen={IsTipsOpen} OnHide={() => setIsTipsOpen(false)} setIsMakeOfferInChat={setIsMakeOfferInChat} tipsData={tipsData} setIsTopMakeOffer={setIsTopMakeOffer} />
        </>
    )
}

export default Chat;
