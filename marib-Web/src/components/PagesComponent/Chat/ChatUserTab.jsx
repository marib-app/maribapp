'use client'
import { formatPriceAbbreviated, placeholderImage, t } from "@/utils";
import { Popover } from "antd";
import Image from "next/image";
import Link from "next/link";
import { HiOutlineDotsVertical } from "react-icons/hi";


const ChatUserTab = ({ activeTab, selectedTabData, systemSettingsData, isBlocked, handleBlockUser, handleUnBlockUser, popoverVisible, setPopoverVisible }) => {

    const isBuyingTab = activeTab === 'buying';
    const userData = isBuyingTab ? selectedTabData?.seller : selectedTabData?.buyer;
    const itemData = selectedTabData?.item;
    const profileImage = userData?.profile || systemSettingsData?.data?.data?.placeholder_image;
    const itemImage = itemData?.image || systemSettingsData?.data?.data?.placeholder_image;
    const CurrencySymbol = systemSettingsData?.data?.data?.currency_symbol


    const content = (userId) => (
        <div>
            {isBlocked ? (
                <p onClick={() => handleUnBlockUser(userId)} style={{ cursor: 'pointer' }}>
                    {t("unblock")}
                </p>
            ) : (
                <p onClick={() => handleBlockUser(userId)} style={{ cursor: 'pointer' }}>
                    {t("block")}
                </p>
            )}
        </div>
    );


    return (
        <div className="chat_user_tab">
            <div className="user_name_img">
                <div className="user_chat_tab_img_cont">
                    <Link href={`/seller/${userData?.id}`}>
                        <Image
                            src={profileImage}
                            alt="User"
                            width={56}
                            height={56}
                            className="user_chat_tab_img"
                            onErrorCapture={placeholderImage}
                        />
                    </Link>
                    <Image
                        src={itemImage}
                        alt="User"
                        width={24}
                        height={24}
                        className="user_chat_small_img"
                        onErrorCapture={placeholderImage} />
                </div>
                <div className="user_det">
                    <Link href={`/seller/${userData?.id}`}>
                        <h6>{userData?.name}</h6>
                    </Link>
                    <p>{itemData?.name}</p>
                </div>
            </div>
            <div className="actual_price">
                <Popover content={content(userData?.id)} trigger="click" placement="bottom" visible={popoverVisible} onVisibleChange={setPopoverVisible}>
                    <span style={{ cursor: 'pointer' }}>
                        <HiOutlineDotsVertical size={22} />
                    </span>
                </Popover>
                <p className="user_chat_tab_time user_chat_money">{CurrencySymbol}{formatPriceAbbreviated(selectedTabData?.item?.price)}</p>
            </div>
        </div>
    )
}

export default ChatUserTab