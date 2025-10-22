'use client'
import SimilarProducts from "@/components/ProductDetails/SimilarProducts";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { FaArrowLeft, FaArrowRight, FaRegLightbulb } from "react-icons/fa6";
import { Swiper, SwiperSlide } from "swiper/react";
import { FreeMode, Pagination } from "swiper/modules";
import "swiper/css";
import "swiper/css/free-mode";
import "swiper/css/pagination";
import { placeholderImage, t, useIsRtl } from "@/utils";
import { allItemApi } from "@/utils/api";
import { useSelector } from "react-redux";
import ReportModal from "@/components/User/ReportModal";
import { FaPlayCircle } from "react-icons/fa";
import NoData from "@/components/NoDataFound/NoDataFound";
import BreadcrumbComponent from "@/components/Breadcrumb/BreadcrumbComponent";
import ReactPlayer from "react-player";
import Loader from "@/components/Loader/Loader";
import { CurrentLanguageData } from "@/redux/reuducer/languageSlice";
import { MdOutlineAttachFile } from "react-icons/md";
import Link from "next/link";
import CustomLightBox from "@/components/ProductDetails/CustomLightBox";
import ProductDescription from "./ProductDescription";
import ProductDetailCard from "./ProductDetailCard";
import SellerCardInProdDet from "./SellerCardInProdDet";
import LocationCardInProdDet from "./LocationCardInProdDet";
import ReportAdCard from "./ReportAdCard";
import OpenInAppDrawer from "./OpenInAppDrawer";
import { useSearchParams } from "next/navigation";


const SingleProductDetail = ({ slug }) => {

    const swiperRef = useRef();
    const isRtl = useIsRtl();
    const systemSettingsData = useSelector((state) => state?.Settings)
    const CurrentLanguage = useSelector(CurrentLanguageData)
    const [productData, setProductData] = useState({});
    const [isBeginning, setIsBeginning] = useState(null);
    const [isEnd, setIsEnd] = useState(null);
    const [activeIndex, setActiveIndex] = useState(0);
    const [displayedImage, setDisplayedImage] = useState();
    const [images, setImages] = useState([])
    const [isLoading, setIsLoading] = useState(false);
    const [isReportModal, setIsReportModal] = useState(false)
    const [thumbnailUrl, setThumbnailUrl] = useState(null);
    const [isVideClicked, setIsVideClicked] = useState(false)
    const [videoUrl, setVideoUrl] = useState('')
    const [currentImage, setCurrentImage] = useState(1)
    const [viewerIsOpen, setViewerIsOpen] = useState(false)
    const displayedImageIndex = images.findIndex(image => image === displayedImage);
    const [IsOpenInApp, setIsOpenInApp] = useState(false)
    const param = useSearchParams()
    const isShare = param.get('share')

    useEffect(() => {
        if (swiperRef && swiperRef?.current) {
            swiperRef?.current?.changeLanguageDirection(isRtl ? 'rtl' : 'ltr');
        }
    }, [isRtl]);

    useEffect(() => {
        if (isShare && window.innerWidth <= 768) {
            setIsOpenInApp(true)
        }
    }, [])


    const fetchProductData = async () => {
        try {
            setIsLoading(true); // Set loading to true when fetching data
            const response = await allItemApi.getItems({
                slug: slug,
                // sort_by: sort_by === "default" ? "" : sort_by // Map "default" to ""
            });
            const responseData = response?.data?.data;
            if (responseData) {
                const { data } = responseData;
                setProductData(data[0]);
                setDisplayedImage(data[0]?.image)
                setIsLoading(false); // Set loading to false after data is fetched
            } else {
                console.error("Invalid response:", response);
            }
        } catch (error) {
            console.error("Error:", error);
        } finally {
            setIsLoading(false); // Set loading to false after data is fetched
        }
    }

    useEffect(() => {
        fetchProductData()
    }, [])

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
        const newIndex = swiperRef?.current?.realIndex;
        setIsEnd(swiperRef?.current?.isEnd);
        setIsBeginning(swiperRef?.current?.isBeginning);
    };

    useEffect(() => {
        const galleryImages = productData?.gallery_images?.map(img => img.image) || [];
        setImages([productData?.image, ...galleryImages])
        if (productData?.video_link !== null) {
            setVideoUrl(productData?.video_link)
            const videoId = getYouTubeVideoId(productData?.video_link)
            if (videoId === false) {
                setThumbnailUrl("")
            } else {
                setThumbnailUrl(`https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`)
            }
        }
    }, [productData])

    const getYouTubeVideoId = (url) => {
        const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
        const match = url?.match(regExp);
        if (match) {
            return (match && match[2].length === 11) ? match[2] : null;
        } else {
            return false
        }
    };

    const handleImageClick = (img, index) => {
        if (isVideClicked) {
            setIsVideClicked(false)
        }
        setActiveIndex(index); // Update active slide index
        setDisplayedImage(img); // Update displayed image
    };

    const handleVideoClick = () => {
        setIsVideClicked(true)
    }

    const breakpoints = {
        0: {
            slidesPerView: 2,
        },
        430: {
            slidesPerView: 2,
        },
        576: {
            slidesPerView: 2.5,
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


    const isPdf = (url) => url?.toLowerCase().endsWith('.pdf');


    const getImageClass = (src) => {
        if (src?.endsWith('.svg') || src?.endsWith('.png')) {
            return 'svgPngBackground'; // Apply background for SVG or PNG
        }
        return 'jpgNoBackround'; // No background for other types like JPG
    };

    const openLightbox = () => {
        setViewerIsOpen(true)
        setCurrentImage(displayedImageIndex)
    }

    return (
        isLoading ? (
            <Loader />
        ) : (
            <>
                <BreadcrumbComponent title2={productData?.name} />
                <section id='product_details_page'>
                    {
                        productData ? (
                            <div className="container">

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
                                                                            onClick={() => handleImageClick(item, index)}
                                                                        />
                                                                    )}
                                                                </div>
                                                            </SwiperSlide>
                                                        ))}
                                                    </Swiper>

                                                    {
                                                        images.length + (videoUrl ? 1 : 0) > 1 &&
                                                        <>
                                                            <button className='pag_leftarrow_cont leftarrow' onClick={swipePrev}>
                                                                <FaArrowLeft className='arrowLeft' />
                                                            </button>
                                                            <button className='pag_rightarrow_cont rightarrow' onClick={swipeNext}>
                                                                <FaArrowRight className='arrowRight' />
                                                            </button>
                                                        </>
                                                    }



                                                </div>
                                            </div>
                                            {productData?.custom_fields?.length > 0 &&
                                                <div className="product_spacs card">
                                                    <div className="highlights">
                                                        <span>
                                                            <FaRegLightbulb size={22} />
                                                        </span>
                                                        <span>
                                                            {t('highlights')}
                                                        </span>
                                                    </div>
                                                    <div className="spacs_list">
                                                        {productData?.custom_fields && productData.custom_fields.map((e, index) => {


                                                            const isValueEmptyArray = e.value === null ||
                                                                e.value === "" ||
                                                                (Array.isArray(e.value) &&
                                                                    (e.value.length === 0 ||
                                                                        (e.value.length === 1 && (e.value[0] === "" || e.value[0] === null))));

                                                            return !isValueEmptyArray && (
                                                                <div className="spac_item" key={index}>
                                                                    <div className="spac_img_title">
                                                                        <div className={getImageClass(e?.image)}>
                                                                            <Image src={e?.image} loading='lazy' alt='spacs_item_img' width={34} height={34} onErrorCapture={placeholderImage} />
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
                                                                            <p>{e?.value}</p>
                                                                        )}
                                                                    </div>
                                                                </div>
                                                            )
                                                        })}

                                                    </div>
                                                </div>
                                            }
                                            <ProductDescription productData={productData} t={t} />
                                        </div>
                                        <div className="col-md-12 col-lg-4">
                                            <ProductDetailCard productData={productData} setProductData={setProductData} systemSettingsData={systemSettingsData} />
                                            <SellerCardInProdDet productData={productData} systemSettingsData={systemSettingsData} />
                                            <LocationCardInProdDet productData={productData} />
                                            {
                                                !productData?.is_already_reported &&
                                                <ReportAdCard productData={productData} setIsReportModal={setIsReportModal} />
                                            }
                                        </div>
                                    </div>
                                </div>
                                <SimilarProducts productData={productData} />
                            </div>
                        ) : (
                            <div>
                                <NoData name={t('data')} />
                            </div>
                        )
                    }
                </section>
                <CustomLightBox lightboxOpen={viewerIsOpen} currentImages={images} currentImageIndex={currentImage} handleCloseLightbox={() => setViewerIsOpen(false)} setCurrentImage={setCurrentImage} />
                {isReportModal && <ReportModal IsReportModalOpen={isReportModal} OnHide={() => setIsReportModal(false)} itemID={productData?.id} setProductData={setProductData} />}
                <OpenInAppDrawer IsOpenInApp={IsOpenInApp} OnHide={() => setIsOpenInApp(false)} systemSettingsData={systemSettingsData} />
            </>
        )
    )
}

export default SingleProductDetail