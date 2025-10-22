'use client'
import { isLogin, t } from "@/utils"
import toast from "react-hot-toast"
import { BsExclamationOctagon } from "react-icons/bs"


const ReportAdCard = ({ productData, setIsReportModal }) => {



    const handleReportAd = () => {

        if (!isLogin()) {
            toast.error(t('loginFirst'))
            return
        }

        setIsReportModal(true)
    }


    return (
        <div className="report_adId_cont">
            <div className="reportLabelCont">
                <div className="reportIconCont">
                    <BsExclamationOctagon size={24} />
                </div>
                <p>{t('reportItmLabel')}</p>
            </div>
            <div className="report_Ad">
                <span>{t('adId')} #{productData?.id}</span>
                <button onClick={handleReportAd} className="reportSeller">{t('reportAd')}</button>
            </div>
        </div>
    )
}

export default ReportAdCard