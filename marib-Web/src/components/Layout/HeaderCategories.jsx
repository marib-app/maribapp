'use client'
import { t } from "@/utils";
import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { FaAngleDown, FaAngleUp } from "react-icons/fa6";
import { IoIosMore } from "react-icons/io";


const HeaderCategories = ({ cateData, headerCatSelected, settings }) => {

    const containerRef = useRef(null);
    const [fitCategoriesCount, setFitCategoriesCount] = useState(0);
    const [IsShowCatDrop, setIsShowCatDrop] = useState(false)
    const [MenuData, setMenuData] = useState(null)
    const [IsShowOtherCat, setIsShowOtherCat] = useState(false)
    const gap = 25;

    useEffect(() => {
        if (IsShowCatDrop || IsShowOtherCat) {
            const allCatWrapper = document.querySelector('.allCatWrapper');
            const cateCont = document.querySelector('.cate_cont');
            if (allCatWrapper && cateCont) {
                cateCont.style.height = `${allCatWrapper.offsetHeight}px`;
            }
        }
    }, [MenuData, IsShowCatDrop, IsShowOtherCat]);

    useEffect(() => {
        if (containerRef.current) {
            const containerWidth = containerRef.current.clientWidth; // Use clientWidth for accurate width
            let totalWidth = 0;
            let count = 0;
            // Create a temporary element to measure the width of category names
            const measureCategoryWidth = (cat) => {
                const haveSubcategories = Array.isArray(cat?.subcategories) && cat.subcategories.length > 0;
                const tempElement = document.createElement('span');
                tempElement.style.display = 'inline-block';
                tempElement.style.visibility = 'hidden';
                tempElement.style.position = 'absolute';
                tempElement.style.whiteSpace = 'nowrap';
                tempElement.innerText = cat.translated_name;
                document.body.appendChild(tempElement);
                const width = tempElement.offsetWidth + (haveSubcategories ? 15 : 12); //icon width(12) + gap(3) between category and
                document.body.removeChild(tempElement);
                return width;
            };
            const otherCategoryWidth = measureCategoryWidth(t('other'));
            // Measure the width of each category until the container is filled

            for (let cat of cateData) {
                const catWidth = measureCategoryWidth(cat);
                // Check if adding the category plus gap fits within the container width
                if (totalWidth + catWidth + (count > 0 ? gap : 0) + otherCategoryWidth <= containerWidth) {
                    totalWidth += catWidth + (count > 0 ? gap : 0); // Add gap if not the first category
                    count++;
                } else {
                    break;
                }
            }
            setFitCategoriesCount(count);
        }
    }, [cateData]);

    const handleCatClick = (cat) => {
        setIsShowCatDrop(true)
        setMenuData(cat)
        if (IsShowOtherCat) {
            setIsShowOtherCat(false)
        }
    }

    const handleCatLinkClick = () => {
        if (IsShowOtherCat) {
            setIsShowOtherCat(false)
        }
        if (IsShowCatDrop) {
            setIsShowCatDrop(false)
        }
    }

    const handleOtherCat = () => {
        setIsShowOtherCat(true)
        setMenuData({})
        if (IsShowCatDrop) {
            setIsShowCatDrop(false)
        }
    }

    const selectCat = () => {
        setIsShowCatDrop(false)
    }

    return (
        <div className='shopping_items_cont'>
            <div className="container">
                <div className="row">
                    <div className="col-12">
                        <div className="shopping_items" ref={containerRef}>
                            {
                                cateData.slice(0, fitCategoriesCount).map((cat) => {
                                    return cat.subcategories_count > 0 ? (

                                        <div className={`shopping_cat ${headerCatSelected === cat?.slug && 'brdrShop'}`} onMouseEnter={() => handleCatClick(cat)} key={cat?.id} onMouseLeave={() => setIsShowCatDrop(false)}>
                                            <span>{cat?.translated_name}</span>
                                            {
                                                cat?.translated_name === MenuData?.translated_name && IsShowCatDrop
                                                    ?
                                                    <span><FaAngleUp className='prof_down_arrow' /></span>
                                                    :
                                                    <span><FaAngleDown className='prof_down_arrow' /></span>
                                            }
                                        </div>
                                    ) : (
                                        <Link href={`/category/${cat?.slug}`} className={`shopping_cat ${headerCatSelected === cat?.slug && 'brdrShop'}`} key={cat?.id} onMouseEnter={handleCatLinkClick}>
                                            {cat?.translated_name}
                                        </Link>
                                    );
                                })
                            }

                            {
                                cateData && cateData.length > fitCategoriesCount &&
                                <div className={`shopping_cat ${IsShowOtherCat || headerCatSelected === 'products' && 'brdrShop'}`} onMouseLeave={() => setIsShowOtherCat(false)} onMouseEnter={handleOtherCat}>

                                    <span>{t('other')}</span>
                                    {
                                        IsShowOtherCat ?
                                            <span><FaAngleUp className='prof_down_arrow' /></span>
                                            :
                                            <span><FaAngleDown className='prof_down_arrow' /></span>
                                    }
                                </div>
                            }

                            {
                                IsShowCatDrop &&
                                <div className="cate_cont_wrap">
                                    <div
                                        className='cate_cont'
                                        onMouseEnter={() => setIsShowCatDrop(true)}
                                        onMouseLeave={() => setIsShowCatDrop(false)}
                                    >

                                        <div className='selected_cat'>
                                            <div className='cat_link_cont'>
                                                <Image src={MenuData?.image ? MenuData?.image : settings?.placeholder_image} width={22} height={22} />
                                                <span>
                                                    {MenuData?.translated_name}
                                                </span>
                                            </div>
                                        </div>

                                        <div className='allCatWrapper'>
                                            {
                                                MenuData?.subcategories_count > 0 && (
                                                    <>
                                                        <Link onClick={selectCat} href={`/category/${MenuData?.slug}`} className='see_all_cat'>{t('seeAllIn')} {MenuData?.translated_name}</Link>
                                                        {
                                                            MenuData?.subcategories.map((sub) => (
                                                                <div className="cate_item cate_subcate" key={sub?.slug}>
                                                                    <Link href={`/category/${sub?.slug}`} className='main_cat' onClick={() => setIsShowCatDrop(false)}>
                                                                        {sub?.translated_name}
                                                                    </Link>
                                                                    {
                                                                        sub?.subcategories_count > 0 &&
                                                                        sub.subcategories.slice(0, 5).map((nestedSub) => (
                                                                            <Link onClick={() => setIsShowCatDrop(false)} href={`/category/${nestedSub?.slug}`} className='subcat' key={nestedSub?.slug}>{nestedSub?.translated_name}</Link>
                                                                        ))
                                                                    }
                                                                    {
                                                                        sub?.subcategories_count > 5 &&
                                                                        <Link onClick={() => setIsShowCatDrop(false)} href={`/category/${sub?.slug}`} className='subcat'>{t('viewAll')}</Link>
                                                                    }
                                                                </div>
                                                            ))
                                                        }
                                                    </>
                                                )
                                            }
                                        </div>
                                    </div>
                                </div>
                            }

                            {
                                IsShowOtherCat &&
                                <div className="cate_cont_wrap">
                                    <div
                                        className='cate_cont'
                                        onMouseLeave={() => setIsShowOtherCat(false)}
                                        onMouseEnter={() => setIsShowOtherCat(true)}
                                    >
                                        <div className='selected_cat'>
                                            <div className='cat_link_cont'>
                                                <IoIosMore size={22} />
                                                <span>
                                                    {t('other')}
                                                </span>
                                            </div>
                                        </div>
                                        <div className='allCatWrapper'>

                                            <Link onClick={() => setIsShowOtherCat(false)} href='/products' className='see_all_cat'>{t('seeAllIn')} {t('other')}</Link>

                                            {
                                                cateData && cateData.slice(fitCategoriesCount).map((sub) => (
                                                    <div className="cate_item cate_subcate" key={sub?.slug}>
                                                        <Link onClick={() => setIsShowOtherCat(false)} href={`/category/${sub?.slug}`} className='main_cat'>
                                                            {sub?.translated_name}
                                                        </Link>
                                                        {
                                                            sub?.subcategories_count > 0 &&
                                                            sub.subcategories.slice(0, 5).map((nestedSub) => (
                                                                <Link onClick={() => setIsShowOtherCat(false)} href={`/category/${nestedSub?.slug}`} className='subcat' key={nestedSub?.slug}>{nestedSub?.translated_name}</Link>
                                                            ))
                                                        }
                                                        {
                                                            sub?.subcategories_count > 5 &&
                                                            <Link onClick={() => setIsShowOtherCat(false)} href={`/category/${sub?.slug}`} className='subcat' key={sub?.slug}>{t('viewAll')}</Link>
                                                        }
                                                    </div>
                                                ))
                                            }

                                        </div>
                                    </div>
                                </div>
                            }
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default HeaderCategories