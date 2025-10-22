'use client'
import { userSignUpData } from "@/redux/reuducer/authSlice"
import { saveOfferData } from "@/redux/reuducer/offerSlice"
import { isLogin, placeholderImage, t } from "@/utils"
import { chatListApi, itemOfferApi } from "@/utils/api"
import Image from "next/image"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { useState } from "react"
import toast from "react-hot-toast"
import { BiPhoneCall } from "react-icons/bi"
import { FaArrowRight } from "react-icons/fa6"
import { IoMdStar } from "react-icons/io"
import { IoChatboxEllipsesOutline } from "react-icons/io5"
import { MdVerifiedUser } from "react-icons/md"
import { useSelector } from "react-redux"
import Swal from "sweetalert2"

const SellerCardInProdDet = ({ productData, systemSettingsData }) => {

    const router = useRouter()
    const userData = productData && productData?.user
    const placeholder_image = systemSettingsData?.data?.data?.placeholder_image
    const [IsStartingChat, setIsStartingChat] = useState(false)
    const loggedInUser = useSelector(userSignUpData)
    const loggedInUserId = loggedInUser?.id


    const extractYear = (dateString) => {
        const date = new Date(dateString);
        return date.getFullYear();
    };

    const memberSinceYear = userData?.created_at ? extractYear(userData.created_at) : '';

    const offerData = {
        itemPrice: productData?.price,
        itemId: productData?.id
    }

    const handleChat = async () => {
        if (!isLogin()) {
            Swal.fire({
                icon: "error",
                title: t('oops'),
                text: t("loginToStartChat"),
                allowOutsideClick: false,
                customClass: {
                    confirmButton: 'Swal-confirm-buttons',
                },
            })
            return;
        }

        if (!productData?.is_already_offered) {
            try {
                setIsStartingChat(true)
                const response = await itemOfferApi.offer({
                    item_id: offerData.itemId,
                });
                const { data } = response.data;
                saveOfferData(data);
            } catch (error) {
                toast.error(t('unableToStartChat'));
                console.log(error);
            }
        }
        else {
            setIsStartingChat(true)
            const offer = productData.item_offers.find((item) => loggedInUserId === item?.buyer_id)
            const offerAmount = offer?.amount
            const offerId = offer?.id

            const selectedChat = {
                amount: offerAmount,
                id: offerId,
                item: {
                    status: productData?.status,
                    price: productData?.price,
                    image: productData?.image,
                    name: productData?.name,
                    review: null,
                },
                user_blocked: false,
                item_id: productData?.id,
                seller: {
                    profile: productData?.user?.profile,
                    name: productData?.user?.name,
                    id: productData?.user?.id,
                },
                tab: 'buying'
            }
            saveOfferData(selectedChat)
        }
        router.push('/chat');
    }



    return (
        <div className="user_profile_card card">
            {
                (userData?.is_verified === 1 || memberSinceYear) &&
                <div className="seller_verified_cont">
                    {
                        userData?.is_verified === 1 &&
                        <div className="verfied_cont">
                            <MdVerifiedUser size={16} />
                            <p className="verified_text">{t('verified')}</p>
                        </div>
                    }
                    {
                        memberSinceYear &&
                        <p className="member_since">
                            {t('memberSince')}: {memberSinceYear}
                        </p>
                    }
                </div>
            }
            <Link href={`/seller/${productData?.user_id}`} className="card-body">
                <div className="profile_sec_Cont">
                    <div className="profile_sec">
                        <Image loading='lazy' src={userData?.profile !== null ? userData?.profile : placeholder_image} alt='profile' className="profImage" width={80} height={80} onErrorCapture={placeholderImage} />
                        <div className="user_details">
                            <span className="user_name" title={userData?.name} >
                                {userData?.name}
                            </span>
                            <div className="seller_Rating_cont">

                                {
                                    productData?.user?.reviews_count > 0 && productData?.user?.average_rating &&
                                    <>
                                        <IoMdStar size={16} />
                                        <p className="seller_rating">{Math.round(productData?.user?.average_rating)} | {productData?.user?.reviews_count} {t('ratings')}</p>

                                    </>
                                }
                            </div>
                            {
                                productData?.user?.show_personal_details === 1 && productData?.user?.email &&
                                <a href={`mailto:${productData?.user?.email}`} className="seller_rating">
                                    {productData?.user?.email}
                                </a>
                            }
                        </div>
                    </div>
                    <FaArrowRight size={24} className="arrow_right" />
                </div>
            </Link>
            <div className="card-footer">
                <button disabled={IsStartingChat} className='chatBtn' onClick={handleChat}>
                    <span><IoChatboxEllipsesOutline size={20} /></span>
                    {
                        IsStartingChat ? <span>{t('startingChat')}</span> : <span>{t('startChat')}</span>
                    }
                </button>
                {
                    productData?.user?.show_personal_details === 1 && productData?.user?.mobile &&
                    <a href={`tel:${productData?.user?.mobile}`} className='chatBtn'>
                        <BiPhoneCall size={21} />
                        <span>{t('call')}</span>
                    </a>
                }
            </div>
        </div>
    )
}

export default SellerCardInProdDet