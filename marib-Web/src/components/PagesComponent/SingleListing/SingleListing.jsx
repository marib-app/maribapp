'use client'
import { useEffect, useRef, useState } from "react";
import { Swiper, SwiperSlide } from "swiper/react";
import { FreeMode, Pagination } from "swiper/modules";
import "swiper/css";
import "swiper/css/free-mode";
import "swiper/css/pagination";
import { FaArrowLeft, FaArrowRight, FaRegLightbulb } from 'react-icons/fa6';
import { MdKeyboardArrowDown, MdOutlineAttachFile } from 'react-icons/md';
import adIcon from '../../../../public/assets/ad_icon.svg'
import NoPackageModal from "@/components/MyListing/NoPackageModal";
import Image from "next/image";
import { isLogin, placeholderImage, t, useIsRtl } from "@/utils";
import { chanegItemStatusApi, getLimitsApi, getMyItemsApi, getPackageApi, renewItemApi } from "@/utils/api";
import Link from "next/link"
import toast from "react-hot-toast";
import { FaPlayCircle } from "react-icons/fa"
import ReactPlayer from "react-player";
import { useDispatch } from "react-redux";
import { setBreadcrumbPath } from "@/redux/reuducer/breadCrumbSlice";
import BreadcrumbComponent from "@/components/Breadcrumb/BreadcrumbComponent";
import SoldOutModal from "./SoldOutModal";
import SoldOutConfirmModal from "./SoldOutConfirmModal";
import CustomLightBox from "@/components/ProductDetails/CustomLightBox";
import ProductDescription from "../SingleProductDetail/ProductDescription";
import MyProdDetail from "./MyProdDetail";
import UpdateMyItemStatus from "./UpdateMyItemStatus";
import LocationCardInProdDet from "../SingleProductDetail/LocationCardInProdDet";
import { useRouter } from "next/navigation";


const SingleListing = ({ slug }) => {


    const router = useRouter()
    const dispatch = useDispatch()
    const swiperRef = useRef();
    const isRtl = useIsRtl();
    const [isBeginning, setIsBeginning] = useState(true);
    const [isEnd, setIsEnd] = useState(false);
    const [SingleListing, setSingleListing] = useState([])
    const [activeIndex, setActiveIndex] = useState(-1);
    const [Status, setStatus] = useState('')
    const [displayedImage, setDisplayedImage] = useState();
    const [IsNoPackageModal, setIsNoPackageModal] = useState(false)
    const [IsGranted, setIsGranted] = useState(false)
    const [IsShowCreateFeaturedAd, setIsShowCreateFeaturedAd] = useState(false)
    const [images, setImages] = useState([])
    const [videoUrl, setVideoUrl] = useState('')
    const [thumbnailUrl, setThumbnailUrl] = useState(null);
    const [isVideClicked, setIsVideClicked] = useState(false)
    const [IsCallSingleListing, setIsCallSingleListing] = useState(false)
    const [IsSoldOutModalOpen, setIsSoldOutModalOpen] = useState(false)
    const [IsSoldOutConfirmModal, setIsSoldOutConfirmModal] = useState(false)
    const [selectedRadioValue, setSelectedRadioValue] = useState(null);
    const [viewerIsOpen, setViewerIsOpen] = useState(false)
    const displayedImageIndex = images.findIndex(image => image === displayedImage);
    const [currentImage, setCurrentImage] = useState(1)
    const [RenewId, setRenewId] = useState('')
    const [ItemPackages, setItemPackages] = useState([])


    useEffect(() => {
        if (swiperRef && swiperRef?.current) {
            swiperRef?.current?.changeLanguageDirection(isRtl ? 'rtl' : 'ltr');
        }
    }, [isRtl]);

    const getSingleListingData = async () => {
        try {
            const res = await getMyItemsApi.getMyItems({ slug: slug })
            setSingleListing(res?.data?.data?.data?.[0])
            const adName = res?.data?.data?.data?.[0]?.name
            setStatus(res?.data?.data?.data?.[0]?.status)
            setDisplayedImage(res?.data?.data?.data?.[0]?.image)
            dispatch(setBreadcrumbPath([
                {
                    name: t('ads'),
                    slug: '/ads'
                },
                {
                    name: adName
                }
            ]))
            if (res?.data?.data?.data?.[0]?.status === 'approved' && res?.data?.data?.data?.[0]?.is_feature === false) {
                setIsShowCreateFeaturedAd(true)
            }
            else {
                setIsShowCreateFeaturedAd(false)
            }
        } catch (error) {
            console.log(error)
        }
    }

    useEffect(() => {
        if (isLogin()) {
            getSingleListingData()
        }
    }, [IsNoPackageModal, IsCallSingleListing])


    useEffect(() => {
        const galleryImages = SingleListing?.gallery_images?.map(img => img.image) || [];
        setImages([SingleListing?.image, ...galleryImages])
        if (SingleListing?.video_link !== null) {
            setVideoUrl(SingleListing?.video_link)
            const videoId = getYouTubeVideoId(SingleListing?.video_link)
            if (videoId === false) {
                setThumbnailUrl("")
            } else {
                setThumbnailUrl(`https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`)
            }
        }
    }, [SingleListing])

    const IsAdExpired = () => {
        if (!SingleListing?.expiry_date) {
            return false;
        }
        const expiryDate = new Date(SingleListing?.expiry_date);
        const currentDate = new Date();
        return expiryDate < currentDate;
    };

    const isExpired = IsAdExpired()

    useEffect(() => {
        if (isExpired) {
            getItemsPackageData()
        }
    }, [isExpired])

    const getItemsPackageData = async () => {
        try {
            const res = await getPackageApi.getPackage({ type: 'item_listing' })
            const { data } = res.data
            setItemPackages(data)
            setRenewId(data[0]?.id)
        } catch (error) {
            console.log(error)
        }
    }

    const getYouTubeVideoId = (url) => {
        const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
        const match = url?.match(regExp);
        if (match) {
            return (match && match[2].length === 11) ? match[2] : null;
        } else {
            return false
        }
    };


    const swipePrev = () => {
        if (displayedImageIndex > 0) { // Check if there's a previous image
            swiperRef?.current?.slidePrev();
            setDisplayedImage(images[displayedImageIndex - 1]);
            setActiveIndex(displayedImageIndex - 1); // Use displayedImageIndex - 1 to reflect the previous index
        }
    };

    const swipeNext = () => {
        if (displayedImageIndex < images.length - 1) { // Check if there's a next image
            swiperRef?.current?.slideNext();
            setDisplayedImage(images[displayedImageIndex + 1]);
            setActiveIndex(displayedImageIndex + 1); // Use displayedImageIndex + 1 to reflect the next index
        }
    };

    const handleSlideChange = () => {
        setIsEnd(swiperRef?.current?.isEnd);
        setIsBeginning(swiperRef?.current?.isBeginning);
    };

    const handleImageClick = (index, item) => {
        setIsVideClicked(false)
        setActiveIndex(index); // Update active slide index
        if (images[index]) {
            setDisplayedImage(item)
        }
    };

    const handleVideoClick = () => {
        setIsVideClicked(true)
    }

    const breakpoints = {
        0: {
            slidesPerView: 2,
        },
        430: {
            slidesPerView: 3,
        },
        576: {
            slidesPerView: 3.5,
        },
        768: {
            slidesPerView: 4,
        },
        1200: {
            slidesPerView: 6,
        },
        1400: {
            slidesPerView: 6,
        },
    };

    const getLimitsData = async () => {
        try {
            const res = await getLimitsApi.getLimits({ package_type: 'advertisement' })
            if (res?.data?.error === false) {
                setIsGranted(true)
            }
        } catch (error) {
            console.log(error)
        }
    }

    const handleCreateFeaturedAd = () => {
        setIsNoPackageModal(true)
        getLimitsData()
    }


    const handleRenewChange = (e) => {
        setRenewId(e.target.value)
    }


    const isPdf = (url) => url?.toLowerCase().endsWith('.pdf');

    const handleSoldOut = () => {
        setIsSoldOutModalOpen(false)
        setIsSoldOutConfirmModal(true)
    }

    const makeItemSoldOut = async () => {
        const res = await chanegItemStatusApi.changeItemStatus({ item_id: SingleListing?.id, status: 'sold out', sold_to: selectedRadioValue })
        if (res?.data?.error === false) {
            toast.success(t('statusUpdated'));
            setIsSoldOutConfirmModal(false)
            setIsCallSingleListing((prev) => !prev)
        } else {
            toast.error(t('failedToUpdateStatus'));
        }
    }

    const openLightbox = () => {
        setViewerIsOpen(true)
        setCurrentImage(displayedImageIndex)
    }

    const handleRenewItem = async () => {
        try {
            const subPackage = ItemPackages.find(p => Number(p.id) === Number(RenewId))
            if (subPackage.is_active === false) {
                toast.error(t('purchasePackageFirst'))
                router.push('/user-subscription')
                return
            }
            const res = await renewItemApi.renewItem({ item_id: SingleListing?.id, package_id: RenewId })

            if (res?.data?.error === false) {
                setSingleListing((prev) => ({
                    ...prev,
                    status: res?.data?.data?.status,
                    expiry_date: res?.data?.data?.expiry_date
                }))
                setStatus(res?.data?.data?.status)
                toast.success(res?.data?.message)
            }
            else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.log(error)
        }
    }


    return (
        <>
            <BreadcrumbComponent />
            <section id='product_details_page'>
                <div className="container">
                    {/* <TopAd /> */}
                    <div className="main_details">
                        <div className="row" id='details_main_row'>
                            <div className="col-md-12 col-lg-8">
                                <div className="gallary_section">
                                    <div className="display_img">
                                        {
                                            isVideClicked == false ? <Image loading="lazy" src={displayedImage} height={0} width={0} alt='display_img' onErrorCapture={placeholderImage} onClick={openLightbox} /> : <ReactPlayer url={videoUrl} controls className="react-player" width="100%"
                                                height="500px" />
                                        }
                                    </div>
                                    <div className={`${images.length + (videoUrl ? 1 : 0) > 1 ? 'gallary_slider' : 'hide_gallery_slider'}`}>
                                        <Swiper
                                            dir={isRtl ? "rtl" : "ltr"}
                                            slidesPerView={6}
                                            className="gallary-swiper"
                                            spaceBetween={20}
                                            freeMode={true}
                                            loop={false}
                                            pagination={false}
                                            modules={[FreeMode, Pagination]}
                                            breakpoints={breakpoints}
                                            onSlideChange={handleSlideChange}
                                            onSwiper={(swiper) => {
                                                swiperRef.current = swiper;
                                                setIsBeginning(swiper.isBeginning);
                                                setIsEnd(swiper.isEnd);
                                            }}
                                        >
                                            {[...images, ...(videoUrl ? [videoUrl] : [])]?.map((item, index) => (
                                                <SwiperSlide key={index} className={index === activeIndex ? 'swiper-slide-active' : ''}>
                                                    <div className={`swiper_img_div ${index === activeIndex ? 'selected' : ''}`}>
                                                        {index === images.length && videoUrl ? (
                                                            <div className="video-thumbnail">
                                                                <div className="thumbnail-container" style={{ height: '8rem' }} onClick={handleVideoClick}>
                                                                    <Image
                                                                        src={thumbnailUrl}
                                                                        width={0}
                                                                        height={0}
                                                                        className='swiper_images'
                                                                        loading='lazy'
                                                                        onErrorCapture={placeholderImage}
                                                                    />
                                                                    <div className="video-overlay" style={{ position: 'relative', bottom: '5rem', left: '3rem' }}>
                                                                        <FaPlayCircle size={24} />
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        ) : (
                                                            <Image
                                                                src={item}
                                                                width={0}
                                                                height={0}
                                                                className='swiper_images'
                                                                loading='lazy'
                                                                onErrorCapture={placeholderImage}
                                                                onClick={() => handleImageClick(index, item)}
                                                            />
                                                        )}
                                                        {/* <Image src={item} width={0} height={0} className='swiper_images' loading='lazy' alt='Product' onErrorCapture={placeholderImage} /> */}
                                                    </div>
                                                </SwiperSlide>
                                            ))}
                                        </Swiper>
                                        <button className='pag_leftarrow_cont leftarrow' onClick={swipePrev}>
                                            <FaArrowLeft size={24} />
                                        </button>
                                        <button className='pag_rightarrow_cont rightarrow' onClick={swipeNext}>
                                            <FaArrowRight size={24} />
                                        </button>
                                    </div>
                                </div>
                                {
                                    IsShowCreateFeaturedAd &&
                                    <div className='feature_ad_section'>
                                        <div className='ad_content'>
                                            <div className='adicon_cont'>
                                                <Image src={adIcon} alt='Ad' width={62} height={75} onErrorCapture={placeholderImage} />
                                            </div>
                                            <p>{t("featureAdPrompt")}</p>
                                        </div>
                                        <button onClick={handleCreateFeaturedAd}>{t("createFeaturedAd")}</button>
                                    </div>
                                }

                                {SingleListing?.custom_fields?.length !== 0 && (
                                    <div className="product_spacs card">
                                        <div className="highlights">
                                            <span>
                                                <FaRegLightbulb size={22} />
                                            </span>
                                            <span>
                                                {t("highlights")}
                                            </span>
                                        </div>
                                        <div className="spacs_list">
                                            {SingleListing?.custom_fields?.map((e, index) => {

                                                const isValueEmptyArray = e.value === null ||
                                                    e.value === "" ||
                                                    (Array.isArray(e.value) &&
                                                        (e.value.length === 0 ||
                                                            (e.value.length === 1 && (e.value[0] === "" || e.value[0] === null))));

                                                return !isValueEmptyArray &&
                                                    (
                                                        <div className="spac_item" key={index}>
                                                            <div className="spac_img_title">
                                                                <div className="spac_item_img">
                                                                    <Image src={e?.image} loading='lazy' alt='spacs_item_img' width={24} height={24} onErrorCapture={placeholderImage} />
                                                                </div>
                                                                <span>
                                                                    {e?.name}
                                                                </span>
                                                            </div>
                                                            <div className="spacs_value">
                                                                <div className="diveder">
                                                                    :
                                                                </div>

                                                                {e.type === 'fileinput' ? (
                                                                    isPdf(e?.value[0]) ? (
                                                                        <div>
                                                                            <MdOutlineAttachFile className='file_icon' />
                                                                            <Link href={e?.value[0]} target="_blank" rel="noopener noreferrer">
                                                                                {t('viewPdf')}
                                                                            </Link>
                                                                        </div>
                                                                    ) : (
                                                                        <Link href={e?.value[0]} target="_blank" rel="noopener noreferrer">
                                                                            <Image src={e?.value[0]} alt="Preview" width={36} height={36} className="file_preview" />
                                                                        </Link>
                                                                    )
                                                                ) : (
                                                                    <p>{Array.isArray(e?.value) ? e?.value.join(', ') : e?.value}</p>
                                                                )}
                                                            </div>
                                                        </div>
                                                    )
                                            }
                                            )}
                                        </div>
                                    </div>
                                )}
                                <ProductDescription productData={SingleListing} t={t} />
                            </div>
                            <div className="col-md-12 col-lg-4">

                                <MyProdDetail SingleListing={SingleListing} t={t} Status={Status} slug={slug} />

                                <UpdateMyItemStatus SingleListing={SingleListing} t={t} Status={Status} setStatus={setStatus} setIsSoldOutModalOpen={setIsSoldOutModalOpen} setIsCallSingleListing={setIsCallSingleListing} />

                                {
                                    isExpired &&
                                    <div className='change_status'>
                                        <p className='status'>{t("renewAd")}</p>
                                        <div className='change_status_content'>
                                            <div className='status_select_wrapper'>
                                                <select name="renew" id="renew" value={RenewId} onChange={handleRenewChange} className='status_select'>
                                                    {
                                                        ItemPackages.map(item => <option value={item?.id} key={item?.id}>{item?.name} - {item.duration} {t('days')}</option>)
                                                    }
                                                </select>
                                                <MdKeyboardArrowDown size={20} className='down_select_arrow' />
                                            </div>
                                            <button onClick={handleRenewItem} className='save_btn'>{t("save")}</button>
                                        </div>
                                    </div>
                                }
                                <LocationCardInProdDet productData={SingleListing} />
                            </div>
                        </div>
                    </div>
                </div>
            </section >

            <CustomLightBox lightboxOpen={viewerIsOpen} currentImages={images} currentImageIndex={currentImage} handleCloseLightbox={() => setViewerIsOpen(false)} setCurrentImage={setCurrentImage} />

            <NoPackageModal IsNoPackageModal={IsNoPackageModal} OnHide={() => setIsNoPackageModal(false)} IsGranted={IsGranted} item_id={SingleListing?.id} />

            <SoldOutModal SingleListing={SingleListing} IsSoldOutModalOpen={IsSoldOutModalOpen} OnHide={() => setIsSoldOutModalOpen(false)} handleSoldOut={handleSoldOut} selectedRadioValue={selectedRadioValue} setSelectedRadioValue={setSelectedRadioValue} />

            <SoldOutConfirmModal isOpen={IsSoldOutConfirmModal} OnHide={() => setIsSoldOutConfirmModal(false)} makeItemSoldOut={makeItemSoldOut} />
        </>
    )
}

export default SingleListing