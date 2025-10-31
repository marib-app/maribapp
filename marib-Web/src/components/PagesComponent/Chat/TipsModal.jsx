
import { Modal } from 'antd'
import { MdClose } from 'react-icons/md'
import { t } from '@/utils'
import { FaCheck } from 'react-icons/fa6'


const TipsModal = ({ IsTipsOpen, OnHide, setIsMakeOfferInChat, tipsData, setIsTopMakeOffer }) => {
    const CloseIcon = <div className="close_icon_cont"><MdClose size={24} color="black" /></div>

    const handleShowMakeOffer = () => {
        OnHide()
        setIsMakeOfferInChat(true)
        if (setIsTopMakeOffer){
            setIsTopMakeOffer(false)
        }
    }

    return (
        <Modal
            centered
            open={IsTipsOpen}
            closeIcon={CloseIcon}
            colorIconHover='transparent'
            className="ant_register_modal"
            onCancel={OnHide}
            footer={null}
            maskClosable={false}
        >
            <div className='makeoffer_modal'>
               
                <div className='safetyTips'>
                    <div className='header'>
                        <h1>{t("safety")} <span>{t("tips")}</span></h1>
                    </div>
                    <div className="tips_list">
                        <div className="row">
                            {tipsData && tipsData.map((ele, index) => (
                                <div className="col-12" key={index}>
                                    <div className="tip">
                                        <div className="tip_correct_icon">
                                            <FaCheck size={18} />
                                        </div>
                                        <div className="tips_desc">
                                            <p>{ele?.translated_name}</p>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                    <div className="continue_button" onClick={handleShowMakeOffer}>
                        <button>{t('continue')}</button>
                    </div>
                </div>
            </div>
        </Modal>
    )
}

export default TipsModal
