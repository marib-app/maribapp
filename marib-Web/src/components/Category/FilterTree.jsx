'use client';
import { Tree } from 'antd';
import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { GoPlus } from "react-icons/go";
import { LuMinus } from 'react-icons/lu';
import { useRouter } from 'next/navigation';
import { setBreadcrumbPath } from '@/redux/reuducer/breadCrumbSlice';
import { t } from '@/utils';
import { usePathname } from 'next/navigation'
import { setCateData, LastPage, setCatLastPage, CurrentPage, setCatCurrentPage, setTreeData, FullTreeData, getSubCategoryPages, setSubCategoryPages } from '@/redux/reuducer/categorySlice'
import { categoryApi, getParentCategoriesApi } from '@/utils/api'
import { setSearch } from '@/redux/reuducer/searchSlice';
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice';

const FilterTree = ({ slug, show, setShow, setCategoryIds }) => {
    const pathname = usePathname()
    const dispatch = useDispatch()
    const router = useRouter()
    const [isExpanded, setIsExpanded] = useState(true)
    const { cateData } = useSelector((state) => state.Category);
    const lastPage = useSelector(LastPage)
    const currentPage = useSelector(CurrentPage)
    const treeData = useSelector(FullTreeData)
    const [Loading, setLoading] = useState(true);
    const initialSelectedKeys = pathname === '/products' ? ['all-categories'] : (slug ? [slug] : []);
    const [selectedKeys, setSelectedKeys] = useState(initialSelectedKeys);
    const [isLoading, setIsLoading] = useState(false);
    const subCategoryPages = useSelector(getSubCategoryPages)
    const [IsLoadMore, setIsLoadMore] = useState(false)
    const [expandedKeys, setExpandedKeys] = useState(['all-categories'])

    const CurrentLanguage = useSelector(CurrentLanguageData)


    useEffect(() => {
        const fetchDataAndSetTree = async () => {
            if (cateData && cateData.length > 0 && treeData && treeData.length === 0) {
                const tree = constructTreeData(cateData, [{ name: t('allCategories'), engName: t('allCategories'), key: 'all-categories', slug: '/products' }]);
                const totalApprovedItems = tree?.length > 0 ? tree?.reduce((sum, cat) => sum + cat.count, 0) : 0;
                dispatch(
                    setTreeData([{
                        title: t("allCategories"),
                        name: t("allCategories"),
                        key: "all-categories",
                        count: totalApprovedItems,
                        path: [{ name: t('products'), engName: t('allCategories'), key: 'all-categories', slug: '/products' }],
                        children: tree
                    }])
                );
            }
        };
        fetchDataAndSetTree();
        setLoading(false)
    }, [treeData]);


    const constructTreeData = (categories, path) => {

        const treeDataPromises = categories?.map((category) => {
            const translation = category.translations?.find(
                (trans) => trans.language_id === CurrentLanguage.id
            );
            const categoryName = translation ? translation.name : category.name;
            const newPath = [...path, { name: categoryName, engName: category.name, slug: category.slug, id: category.id, translations: category.translations }];
            let totalApprovedItems = 0
            totalApprovedItems += category?.all_items_count

            return {
                title: categoryName,
                key: category?.slug,
                slug: category?.slug,
                name: category.name,
                id: category?.id,
                count: totalApprovedItems,
                path: newPath,
                children: [],
                isLeaf: category?.subcategories_count === 0,
                translations: category.translations,
            }

        });

        return treeDataPromises;
    };

    const getParentCategories = async () => {
        try {
            const res = await getParentCategoriesApi.getPaymentCategories({ slug, tree: 0 })
            const data = res?.data?.data

            setExpandedKeys(prevExpandedKeys => {
                const newExpandedKeys = [...prevExpandedKeys]; // Copy current expanded keys

                data.forEach(item => {
                    if (item?.slug && !newExpandedKeys.includes(item.slug)) {
                        // Only push if slug is not already present
                        newExpandedKeys.push(item.slug);
                    }
                });

                // Return the updated expanded keys
                return newExpandedKeys;
            });

        } catch (error) {
            console.log(error)
        }
    }


    const updateCategoryNamesWithTranslation = (treeData, CurrentLanguage) => {
        return treeData.map((node) => {

            const nodeTranslation = node?.translations?.find(
                (trans) => trans.language_id === CurrentLanguage.id
            );

            const updatedPath = node?.path?.map((pathItem) => {
                const pathItemTranslation = pathItem.translations?.find(
                    (trans) => trans.language_id === CurrentLanguage.id
                );

                const translatedName = pathItemTranslation ? pathItemTranslation.name : pathItem.engName;

                const updatedPathItem = {
                    ...pathItem,
                    name: pathItem.key === 'all-categories' ? t('allCategories') : translatedName, // Set translated name for 'all-categories'
                };

                return updatedPathItem
            });

            const nodaName = node.key === 'all-categories' ? t('allCategories') : (nodeTranslation ? nodeTranslation.name : node.name);

            // If the node has children, apply the function recursively
            return {
                ...node,
                title: nodaName,
                path: updatedPath,
                children: node.children
                    ? updateCategoryNamesWithTranslation(node.children, CurrentLanguage) // Recursively update children
                    : [],
            };
        });
    };

    useEffect(() => {
        if (treeData.length > 0) {

            // Update the treeData with translated names
            dispatch(setTreeData(updateCategoryNamesWithTranslation(treeData, CurrentLanguage)));
        }
    }, [CurrentLanguage]);

    const fetchData = async (id, path, key, page = 1) => {
        try {
            const response = await categoryApi.getCategory({ category_id: id, page });
            const { data } = response?.data?.data;
            const currentPage = response.data.data.current_page
            const lastPage = response.data.data.last_page
            const isLoadMore = currentPage < lastPage
            const updatedSubCategoryPages = { ...subCategoryPages, [key]: { currentPage, lastPage } }
            dispatch(setSubCategoryPages(updatedSubCategoryPages))


            const subcategories = data.map(subcategory => {
                const subcategoryTranslation = subcategory.translations?.find(
                    (trans) => trans.language_id === CurrentLanguage.id
                );
                const subcategoryName = subcategoryTranslation ? subcategoryTranslation.name : subcategory.name;

                return {
                    title: subcategoryName, // Use the translated name for title
                    key: subcategory.slug,
                    slug: subcategory.slug,
                    id: subcategory.id,
                    name: subcategory.name,
                    count: subcategory.all_items_count,
                    path: [
                        ...path,
                        { name: subcategoryName, engName: subcategory.name, slug: subcategory.slug, id: subcategory.id, translations: subcategory.translations }
                    ],
                    children: [], // Set children to an empty array for now
                    isLeaf: subcategory.subcategories_count === 0,
                    translations: subcategory.translations
                };
            });
            // Add load more option if applicable
            if (isLoadMore) {
                subcategories.push({
                    title: t("loadMore"), // Ensure 't' is defined or imported
                    name: t("loadMore"),
                    key: `loadMoreSubcategories_${key}`,
                    getMoreKey: key,
                    isLoadMore: true,
                    isLeaf: true,
                    id,
                    selectable: false,
                    path: path
                });
            }
            return {
                subcategories, // Return the modified array of subcategories
                currentPage,
                lastPage
            };
        } catch (error) {
            console.log(error);
            return { subcategories: [], currentPage: 1, lastPage: 1 };
        }
    };


    const updateTreeData = (treeData, key, newChildren) => {
        return treeData?.map((node) => {
            if (node.key === key) {
                const updatedChildren = (node.children || []).filter(child => !child.isLoadMore);

                return {
                    ...node,
                    children: [...updatedChildren, ...newChildren],
                };
            }
            // If not found, check the children recursively
            if (node.children) {
                return {
                    ...node,
                    children: updateTreeData(node.children, key, newChildren),
                };
            }
            return node; // Return the node unchanged if not found
        });
    };

    const fetchMoreSubcategory = async (id, path, key, page) => {
        setIsLoadMore(true)
        const { subcategories } = await fetchData(id, path, key, page);
        const updatedData = updateTreeData(treeData, key, subcategories)
        dispatch(setTreeData(updatedData));
        setIsLoadMore(false)
    };
    const renderTreeNode = (node) => {
        const isBold = node.key === 'all-categories';
        const isSelected = selectedKeys.includes(node.key);
        const isAllCatSelected = selectedKeys.includes('all-categories')
        return (
            <div className={`filter_item_cont ${(isSelected || isAllCatSelected) ? 'selected' : ''}`}>

                {
                    node.isLoadMore ?
                        IsLoadMore ?
                            <span className="loadMore_label">Loading...</span>
                            :
                            <span className="loadMore_label" onClick={() => fetchMoreSubcategory(node?.id, node.path, node?.getMoreKey, subCategoryPages[node.getMoreKey]?.currentPage + 1)}>
                                {node?.title}
                            </span>
                        :
                        <>
                            <span className={`filter_item ${isBold ? 'bold' : ''}`}>{node?.title}</span>
                            <span className={`filter_item_count ${isBold ? 'bold' : ''}`}>({node.count})</span>
                        </>
                }
            </div>
        );
    };

    const switcherIcon = (node) => {
        const isBold = node?.data?.key === 'all-categories';
        const iconColor = isBold ? 'black' : '#595b6c';
        return node?.expanded ? <LuMinus size={14} color={iconColor} fontWeight={600} /> : <GoPlus size={14} color={iconColor} fontWeight={600} />;
    };

    const onSelect = (selectedKeys, info) => {
        if (selectedKeys.length === 0) {
            return
        }
        if (show) {
            setShow(false)
        }
        dispatch(setSearch(''))
        setSelectedKeys(selectedKeys);
        const newSlug = info?.node?.key;
        if (selectedKeys.includes('all-categories')) {
            router.replace('/products');
        } else {
            router.replace(`/category/${newSlug}`);
        }

    };
    const findNodeById = (nodes, id) => {
        // Loop through each node in the current level
        for (let node of nodes) {
            // Check if the current node's key matches the id we're looking for
            if (node.key === id) {
                return node; // Return the node if found
            }

            // If the node has children, search recursively
            if (node.children) {
                const found = findNodeById(node.children, id);
                if (found) {
                    return found; // Return the found node from children
                }
            }
        }
    };



    useEffect(() => {

        if (treeData && treeData.length > 0 && slug) {

            const selectedNode = findNodeById(treeData, slug);
            if (selectedNode) {

                dispatch(setBreadcrumbPath(selectedNode.path));
                const parentCategories = selectedNode.path.slice(1);
                // Extract the IDs and join them into a comma-separated string
                const parentCategoryIds = parentCategories.map(category => category.id).join(',');
                if (typeof setCategoryIds === 'function') {
                    setCategoryIds(parentCategoryIds);
                }
                setSelectedKeys([selectedNode?.key]);

                setExpandedKeys(prevExpandedKeys => {
                    if (!prevExpandedKeys.includes(selectedNode?.key)) {
                        return [...prevExpandedKeys, selectedNode?.key];
                    }
                    return prevExpandedKeys;
                });
            }
            else {
                getParentCategories()
            }
        }
    }, [treeData, CurrentLanguage, slug]);

    const fetchMoreCategory = async () => {
        setIsLoading(true);
        try {

            const response = await categoryApi.getCategory({ page: `${currentPage + 1}` });
            const { data } = response.data;

            const newTreeData = await constructTreeData(data.data, [{ name: t('allCategories'), engName: t('allCategories'), key: 'all-categories', slug: '/products' }]);

            const updatedData = updateTreeData(treeData, 'all-categories', newTreeData)

            dispatch(setTreeData(updatedData));
            // Update pagination state
            dispatch(setCateData([...cateData, ...data.data]));
            dispatch(setCatLastPage(data?.last_page));
            dispatch(setCatCurrentPage(data?.current_page));
        } catch (error) {
            console.error("Error:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const handleLoadData = async (node) => {
        if (node.children.length === 0 && !node.isLeaf) {
            const { subcategories } = await fetchData(node?.id, node.path, node?.key);
            setExpandedKeys(prev => {
                if (!prev.includes(node?.key)) {
                    return [...prev, node?.key];
                }
                return prev; // Return the unchanged array if key is already present
            });
            // Merge the newly loaded subcategories with the existing tree data
            const updatedData = updateTreeData(treeData, node.key, subcategories)
            dispatch(setTreeData(updatedData))
        }
    };

    const handleAllCategoryExpansion = (_, { expanded, node }) => {
        let newExpandedKeys
        if (expanded) {
            if (!expandedKeys.includes(node?.key)) {
                newExpandedKeys = [...expandedKeys, node?.key];
            }
        } else {
            newExpandedKeys = expandedKeys.filter(key => key !== node?.key);
        }

        setExpandedKeys(newExpandedKeys);
    };


    return (
        !Loading &&
        <div>
            {
                treeData && treeData?.length > 0 &&
                <Tree
                    treeData={treeData}
                    titleRender={(node, index) => renderTreeNode(node, index === 0)}
                    className="catTree"
                    switcherIcon={(node) => switcherIcon(node)}
                    defaultExpandAll={false}
                    selectedKeys={selectedKeys}
                    onSelect={onSelect}
                    loadData={handleLoadData}
                    expandedKeys={expandedKeys}
                    onExpand={handleAllCategoryExpansion}
                />
            }

            {
                isLoading ?
                    <div className="loader adListingLoader"></div>
                    :
                    isExpanded && currentPage < lastPage &&
                    <div className="loadMore">
                        <button onClick={fetchMoreCategory}> {t('loadMore')} </button>
                    </div>
            }
        </div>
    );
};

export default FilterTree;